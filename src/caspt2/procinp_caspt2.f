************************************************************************
* This file is part of OpenMolcas.                                     *
*                                                                      *
* OpenMolcas is free software; you can redistribute it and/or modify   *
* it under the terms of the GNU Lesser General Public License, v. 2.1. *
* OpenMolcas is distributed in the hope that it will be useful, but it *
* is provided "as is" and without any express or implied warranties.   *
* For more details see the full text of the license in the file        *
* LICENSE or in <http://www.gnu.org/licenses/>.                        *
************************************************************************
      Subroutine ProcInp_Caspt2
CSVC: process CASPT2 input based on the data in the input table, and
C initialize global common-block variables appropriately.
      Use InputData
      Implicit None
#include "rasdim.fh"
#include "warnings.fh"
#include "caspt2.fh"
#include "output.fh"
#include "pt2_guga.fh"
#include "WrkSpc.fh"
#include "stdalloc.fh"
#include "SysDef.fh"
#include "ofembed.fh"
#include "para_info.fh"

      Integer iDummy

* Number of non-valence orbitals per symmetry
      Integer nCore(mxSym)
      Integer nDiff, NFI, NSD
* Geometry-determining root
      Logical Is_iRlxRoot_Set
* Cholesky stuff
      Logical REORD,DECO,timings
      Integer Algo
      COMMON /CHORAS  / REORD,DECO,ALGO
      COMMON /CHOTIME / timings

      Integer I, J, M, N
      Integer ISYM
* State selection
      Integer iGroup, IOFF
* Error condition
      Integer IERR

#include "chocaspt2.fh"

      CALL QENTER('READIN')

* basis of 0-order hamiltonian?
      HZERO = Input % HZero
      If (HZERO.NE.'STANDARD'.AND.HZERO.NE.'CUSTOM') Then
        call WarningMessage(2,
     &   'invalid 0-order hamiltonian: '//TRIM(HZERO))
        call Quit_OnUserError
      End If
* Choose Focktype, reset IPEA shift to 0 for non-standard fock matrices
      FOCKTYPE = Input % FockType
      IF (FOCKTYPE.ne.'STANDARD') Then
        If (IfChol) Then
          Call WarningMessage(2,'Requested FOCKTYPE not possible.')
          WRITE(6,*)'Calculations using Cholesky vectors can only'
          WRITE(6,*)'be used with the standard focktype!'
          Call Quit_OnUserError
        End If
        BSHIFT=0.0D0
        HZERO = TRIM(HZERO)//' WITHOUT IPEA'
        If (IPRGLB.ge.TERSE) Then
          Call WarningMessage(1,
     &         'non-standard focktype, IPEA not active!')
        End If
      ELSE
* user-specified IPEA shift or not?
        If (Input % IPEA) Then
          BSHIFT = Input % BSHIFT
          HZERO = TRIM(HZERO)//' WITH CUSTOM IPEA'
        Else
          BSHIFT=0.25D0
          HZERO = TRIM(HZERO)//' WITH DEFAULT IPEA'
        End If
      END IF
* print warnings if deviating from the default
      If (HZERO.NE.'STANDARD WITH DEFAULT IPEA'.OR.
     &    FOCKTYPE.NE.'STANDARD') Then
        IF (IPRGLB.ge.TERSE) THEN
          Call WarningMessage(1,'User-modified 0-order hamiltonian!')
        End If
      End If
* real/imaginary shifts
      SHIFT = Input % Shift
      SHIFTI = Input % ShiftI
* RHS algorithm selection
#ifdef _MOLCAS_MPP_
#  ifdef _GA_
C     The RHS on-demand algorithm doesn't handle serial calculations
C     because it's not adapted for use with regular Work arrays, only
C     global arrays, and needs to be switched off (using rhsall instead)
      RHSDIRECT=(Is_Real_Par().AND.Input%RHSD)
#  else
C     Without the Global Arrays library, we can't use the RHSALL2
C     and ADDRHS algorithms in parallel. Here we force the use of
C     RHS on-demand instead, depending on if the calculation is
C     really parallel or not.
      RHSDIRECT=Is_Real_Par()
#  endif
#else
      RHSDIRECT=.False.
#endif

* Cholesky: set defaults if it was not called during input
      If (.NOT.(Input % ChoI .or. Input % Chol)) Then
        Call Cho_caspt2_rdInp(.True.,iDummy)
      End If

*---  Initialize
      IDCIEX=0
      IEOF1M=0
      DO I=1,64
        IAD1M(I)=-1
      END DO
      RFpert = Input % RFPert

      NTIT=0
      OUTFMT='DEFAULT'
      G1SECIN=.FALSE.
      PRORB=.TRUE.
      PRSD=.FALSE.
      NCASES=13
      JMS=.FALSE.
      NLYROOT=0

      DoCumulant = Input%DoCumulant
      DoTranRDM  = Input%DoTranRDM
      DoExactRDM = Input%DoExactRDM

************************************************************************
*
* Root selection
*
************************************************************************
*SVC: create a flat array, putting regular MS states first with
* the group number increasing, then put groups of XMS states.
* Example: lets say the input is:
* MULTistate
*  3 3 4 5
* XMULtistate
*  2
*  2 1 2
*  4 6 7 8 9
* Then the arrays that are created will be:
* nstate = 9
* mstate(nstate): 3 4 5 1 2 6 7 8 9
* nGroup = 5
* nGroupState(nGroup): 1 1 1 2 4
      NSTATE = 0
      MSTATE = 0
      NGROUP = 0
      NGROUPSTATE = 0
      If(Input%MULT) Then
        If (Input%AllXMult) Then
          Call WarningMessage(2,'Keyword MULT cannot be used together'//
     &                          'with XMUL=ALL.')
          Call Quit_OnUserError
        End If
        Do I=1,Input%nMultState
          NGROUP = NGROUP + 1
          NGROUPSTATE(NGROUP) = 1
          MSTATE(I) = Input%MultGroup%State(I)
          NSTATE = NSTATE + 1
        End Do
      End If
      IOFF=NSTATE
      If(Input%XMUL) Then
        If (Input%AllMult) Then
          Call WarningMessage(2,'Keyword XMUL cannot be used together'//
     &                          'with MULT=ALL.')
          Call Quit_OnUserError
        End If
        Do iGroup=1,Input%nXMulGroup
          NGROUP = NGROUP + 1
          NGROUPSTATE(NGROUP) = Input%nXMulState(iGroup)
          Do I=1,Input%nXMulState(iGroup)
            MSTATE(IOFF+I) = Input%XMulGroup(iGroup)%State(I)
            NSTATE = NSTATE + 1
          End Do
          IOFF = IOFF + Input%nXMulState(iGroup)
        End Do
      End If
* The LROOt keyword specifies a single root to be used. It should not be
* used together with either MULT or XMUL keywords.
      If (Input%LROO) Then
        If (Input%MULT.OR.Input%XMUL) Then
          Call WarningMessage(2,'Keyword LROO cannot be used together'//
     &                          'with the MULT or XMUL keywords.')
          Call Quit_OnUserError
        End If
        NSTATE=1
        MSTATE(1)=Input%SingleRoot
        NGROUP=1
        NGROUPSTATE(1)=1
      End If
* If still nothing was selected, we should default to computing all the
* roots that were part of the rasscf orbital optimization.
      IF(NSTATE.EQ.0) THEN
        NSTATE=NROOTS
        MSTATE=IROOT
        If (Input%AllXMult) Then
          NGROUP=1
          NGROUPSTATE(1)=NSTATE
        Else
          NGROUP=NSTATE
          NGROUPSTATE(1:NGROUP)=1
        End If
      END IF
* Finally, some sanity checks.
      IF(NSTATE.LE.0.OR.NSTATE.GT.MXROOT) Then
        Call WarningMessage(2,'Number of states is <0 or too large.')
        WRITE(6,'(a,i8)')' NSTATE = ',NSTATE
        WRITE(6,*)' Check usage of keywords MULT/XMUL.'
        Call Quit_OnUserError
      END IF
* setup root to state translation
      ROOT2STATE = 0
      DO I=1,NSTATE
        ROOT2STATE(MSTATE(I))=I
      END DO
*
* Relax root selection
*
      iRlxRoot=-1
      Call Qpg_iScalar('NumGradRoot',Is_iRlxRoot_Set)
      If (Is_iRlxRoot_Set) Then
          Call Get_iScalar('NumGradRoot',iRlxRoot)
      End If
      If (Input % RlxRoot.gt.0) iRlxRoot=Input%RlxRoot
      If (iRlxRoot.eq.-1) iRlxRoot=NSTATE
      If (iRlxRoot.gt.NSTATE) Then
        If (IPRGLB.GE.TERSE) then
         Call WarningMessage(1,'Too large iRlxRoot.')
         WRITE(6,*)' Reset to NSTATE=',NSTATE
        End If
        iRlxRoot=NSTATE
      End If

************************************************************************
*
* Determine number of Frozen/Deleted orbitals
*
************************************************************************
* The number of Frozen orbitals is initially read from the reference
* wavefunction. Here, we modify that number to be the larger of what
* was in the reference and the non-valence orbitals.
      Call Get_iArray('Non valence orbitals',nCore,nSym)
      Do iSym = 1, nSym
        If (nCore(iSym).gt.nFro(iSym)) Then
          nDiff=nCore(iSym)-nFro(iSym)
          nDiff=min(nDiff,nISh(iSym))
          nFro(iSym)=nFro(iSym)+nDiff
          nISh(iSym)=nISh(iSym)-nDiff
        End If
      End Do
* If a user specified the number of frozen orbitals explicitely, then
* that number overwrites the automatically chosen numbers, but it we
* warn the user and report what the computed number was.
      IF(Input % FROZ) THEN
        IF(IPRGLB.GE.TERSE) THEN
          Call WarningMessage(1,'User changed nr of frozen orbitals.')
        END IF
        IERR=0
        DO I=1,NSYM
          NFI=NFRO(I)+NISH(I)
          IF(NFI.LT.Input%nFro(I)) THEN
            Call WarningMessage(2,'Too many frozen orbitals!')
            Call Quit_OnUserError
          ELSE
            nFro(I)=Input%nFro(I)
          END IF
          NISH(I)=NFI-nFro(I)
        END DO
      ENDIF
* Set user-specified number of deleted orbitals.
      IF(Input % DELE) THEN
        IERR=0
        DO I=1,NSYM
          NSD=NSSH(I)+NDEL(I)
          IF(NSD.LT.Input%nDel(I)) THEN
            Call WarningMessage(2,'Too many deleted orbitals!')
            Call Quit_OnUserError
          ELSE
            NDEL(I)=Input%nDel(I)
          END IF
          NSSH(I)=NSD-nDel(I)
        ENDDO
      ENDIF

* NOT TESTED
#if 0
************************************************************************
*
* Orbital-free embedding.
*
************************************************************************
      Done_OFemb=.false.
      First_OFE =.true.
      ipFMaux = -666666
      If (Input % OFEmbedding) Then
        Done_OFemb=.true.
        write(6,*)
        write(6,*)  '  --------------------------------------'
        write(6,*)  '   Orbital-Free Embedding Calculation   '
        write(6,*)  '  --------------------------------------'
        write(6,*)
      End If
#endif
************************************************************************
*
* Determine what kind of calculations are needed/requested.
*
************************************************************************
* flags for enabling/disabling sections
      IFPROP = Input % Properties
      IFDENS = Input % DENS
      IFMIX = .NOT.Input % NoMix
      IFMSCOUP = (Input % MULT .OR. Input % XMUL)
     &           .AND.(.NOT.Input % NoMult)

* Choice? of preprocessing route
      ORBIN='TRANSFOR'

*---  Expectation values of H0 needed or not? Spectral resolution?
      BMATRIX='YES     '
      BTRANS ='YES     '
      BSPECT ='YES     '
*---  Overlap matrix needed? Linear dependence removal needed?
      SMATRIX='YES     '
      SDECOM ='YES     '
C Presently, we always need the ON transformation/Lindep removal.
C Consistency of these demands:
      IF(BSPECT.NE.'NO      ') BTRANS ='YES     '
      IF(BTRANS.NE.'NO      ') BMATRIX='YES     '
      IF(BTRANS.NE.'NO      ') SDECOM ='YES     '
      IF(SDECOM.NE.'NO      ') SMATRIX='YES     '

************************************************************************
*
* Thresholds
*
************************************************************************
      If (Input%THRE) Then
        If (IPRGLB.GE.TERSE) THEN
          Call WarningMessage(1,
     &          'User modified linear dependency thresholds!')
        End If
      End If
      THRSHN=Input%THRSHN
      THRSHS=Input%THRSHS
      THRCONV=Input%THRCONV
      CITHR=Input%PrWF
      THRENE=5.0d+01
      THROCC=5.0d-04
      MAXIT=Input%MaxIter
      DNMTHR=Input%DNMTHR
      CMPTHR=Input%CMPTHR
      CNTTHR=Input%CNTTHR

*---  Create the symmetry multiplication table
      MUL(1,1)=1
      M=1
      DO N=1,3
        DO I=1,M
          DO J=1,M
            MUL(I+M,J)=M+MUL(I,J)
            MUL(I,J+M)=MUL(I+M,J)
            MUL(I+M,J+M)=MUL(I,J)
          END DO
        END DO
        M=2*M
      END DO
*
*---  Exit
      CALL QEXIT('PROC_INP')
      Return
      End
