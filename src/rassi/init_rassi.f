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
      SUBROUTINE INIT_RASSI
      IMPLICIT REAL*8 (A-H,O-Z)
#include "prgm.fh"
      CHARACTER*16 ROUTINE
      PARAMETER (ROUTINE='INIT')
#include "Molcas.fh"
#include "cntrl.fh"
#include "symmul.fh"
#include "Files.fh"
#include "WrkSpc.fh"
#include "rassi.fh"
      Logical FoundTwoEls,DoCholesky

      CALL QENTER(ROUTINE)


C SET UP SYMMETRY MULTIPLICATION TABLE:
      MUL(1,1)=1
      M=1
      DO  N=1,3
        DO  I=1,M
          DO J=1,M
            MUL(I+M,J)=M+MUL(I,J)
            MUL(I,J+M)=MUL(I+M,J)
            MUL(I+M,J+M)=MUL(I,J)
          END DO
        END DO
        M=2*M
      END DO

C LNILPT - WORK(LNILPT) IS A VALID DUMMY FIELD
      CALL GETMEM('NilPt','ALLO','REAL',LNILPT,1)
      CALL GETMEM('INilPt','ALLO','INTE',LINILPT,1)

C UNIT NUMBERS AND NAMES
      LUONE=2
      FNONE='ONEINT'
      LUORD=30
      FNORD='ORDINT'
      LUCOM=33
      FNCOM='COMFILE'
      LUIPH=15
      LUSCR=20
      FNSCR='SCRATCH'
      LUEXC=22
      FNEXC='ANNI'
      LUEXT=21
      FNEXT='EXTRACT'
      LUMCK=33
      LuToM=26
      FnToM='TOFILE'
      LuEig=27
      FnEig='EIGV'
      DO  I=1,MXJOB
        JBNAME(I)='UNDEFINE'
      END DO
      DO  I=1,MXJOB
        WRITE(MINAME(I),'(''MCK'',I3.3)') I
      END DO
      IF(IPGLOB.GT.VERBOSE) THEN
        WRITE(6,*)' Unit numbers and names:'
        WRITE(6,'(1x,I8,5x,A8)')LUONE,FNONE
        WRITE(6,'(1x,I8,5x,A8)')LUORD,FNORD
        WRITE(6,'(1x,I8,5x,A8)')LUSCR,FNSCR
        WRITE(6,'(1x,I8,5x,A8)')LUEXC,FNEXC
      END IF

      IF(IPGLOB.GT.VERBOSE) WRITE(6,*)' OPENING ',FNSCR
      CALL DANAME(LUSCR,FNSCR)
      IF(IPGLOB.GT.VERBOSE) WRITE(6,*)' OPENING ',FNEXC
      CALL DANAME(LUEXC,FNEXC)


C NR OF JOBIPHS AND STATES:
      NJOB=0
      NSTATE=0
      IF(IPGLOB.GT.VERBOSE) THEN
       WRITE(6,*)' INITIAL DEFAULT VALUES:'
       WRITE(6,'(1X,A,I4)')'  NJOB:',NJOB
       WRITE(6,'(1X,A,I4)')'NSTATE:',NSTATE
      END IF
C
      LHAM=ip_Dummy
      LESHFT=ip_Dummy
      LHdiag=ip_Dummy

C NR OF OPERATORS FOR WHICH MATRIX ELEMENTS ARE TO BE CALCULATED:
      NPROP=0

C OPERATORS FOR WHICH MATRIX ELEMENTS OVER SPIN-ORBIT EIGENSTATES
C ARE TO BE COMPUTED.
      NSOPR=0

C DEFAULT THRESHOLD FOR PRINTING CI COEFFICIENTS:
      CITHR=0.05d0

C DEFAULT THRESHOLD FOR PRINTING TRANSITION DIPOLE VECTORS
      TDIPMIN=1.0D-4

C DEFAULT THRESHOLD AND MAX NUMBER OF SO-HAMILTONIAN
C MATRIX ELEMENTS TO PRINT:
      NSOTHR_PRT=0
      SOTHR_PRT=-1.0D0

C DEFAULT FLAGS:
      PRSXY=.FALSE.
      PRDIPVEC=.FALSE.
      PRORB=.FALSE.
      PRTRA=.FALSE.
      PRCI=.FALSE.
      IFHAM=.FALSE.
      IFEJOB=.FALSE.
      IFSHFT=.FALSE.
      IFHDIA=.FALSE.
      IFHEXT=.FALSE.
      IFHEFF=.FALSE.
      IFHCOM=.FALSE.
      HAVE_HEFF=.FALSE.
      HAVE_DIAG=.FALSE.
      IFSO=.FALSE.
      NATO=.FALSE.
      BINA=.FALSE.
      NONA=.FALSE.
      IFTRD1=.FALSE.
      IFTRD2=.FALSE.
      RFPERT=.FALSE.
      ToFile=.false.
      PRXVR=.FALSE.
      PRXVE=.FALSE.
      PRXVS=.FALSE.
      PRMER=.FALSE.
      PRMEE=.FALSE.
      PRMES=.FALSE.
      IFGCAL=.FALSE.
      EPRTHR=0.0D0
      IFXCAL=.FALSE.
      IFMCAL=.FALSE.
      HOP=.FALSE.
      TRACK=.FALSE.
      ONLY_OVERLAPS=.FALSE.
* Intesities
      DIPR=.FALSE.
      OSTHR_DIPR = 0.0D0
      QIPR=.FALSE.
      OSTHR_QIPR = 0.0D0
      QIALL=.FALSE.
* Exact operator
      Do_TMOS=.FALSE.
      DO_KVEC=.FALSE.
      NKVEC=0
      PRRAW=.FALSE.
      PRWEIGHT=.FALSE.
      NEW_TOLERANCE=.FALSE.
      TOLERANCE=0.1D0
      REDUCELOOP=.FALSE.
      LOOPDIVIDE=0
cnf
      IfDCpl = .False.
cnf

C K. Sharkas  BEG
      IFATCALSA=.FALSE.
      IFGTCALSA=.FALSE.
      IFGTSHSA=.FALSE.
C K. Sharkas  END

c BP - Hyperfine tensor and SONATORB initialization
      IFACAL=.FALSE.
      IFACALFC=.TRUE.
      IFACALSD=.TRUE.

      NOSO=.FALSE.
      SONATNSTATE=0
      SODIAGNSTATE=0

      IFCURD=.FALSE.

      Do_TMOS=.FALSE.
      Do_SK  =.FALSE.
      L_Eff=5
      k_vector(1) = 0.0D0
      k_vector(2) = 0.0D0
      k_vector(3) = 0.0D0

* Nr of states for which natural orbitals will be computed:
      NRNATO=0
* Nr of state pairs for computing bi-natural orbitals:
      NBINA=0

* Check if two-electron integrals are available:
      Call f_Inquire('ORDINT',FoundTwoEls)
      Call DecideOnCholesky(DoCholesky)
      If (FoundTwoEls .or. DoCholesky) IFHAM=.True.

      IF(IPGLOB.GE.DEBUG) THEN
        WRITE(6,*)'Initial default flags are:'
        WRITE(6,*)'     PRSXY :',PRSXY
        WRITE(6,*)'     PRORB :',PRORB
        WRITE(6,*)'     PRTRA :',PRTRA
        WRITE(6,*)'     PRCI  :',PRCI
        WRITE(6,*)'     IFHAM :',IFHAM
        WRITE(6,*)'     IFHEXT:',IFHEXT
        WRITE(6,*)'     IFHEFF:',IFHEFF
        WRITE(6,*)'     IFEJOB:',IFEJOB
        WRITE(6,*)'     IFSHFT:',IFSHFT
        WRITE(6,*)'     IFHDIA:',IFHDIA
        WRITE(6,*)'     IFHCOM:',IFHCOM
        WRITE(6,*)'     IFSO  :',IFSO
        WRITE(6,*)'     NATO  :',NATO
        WRITE(6,*)'     IFTRD1:',IFTRD1
        WRITE(6,*)'     IFTRD2:',IFTRD2
        WRITE(6,*)'     RFPERT:',RFPERT
        WRITE(6,*)'     TOFILE:',ToFile
        WRITE(6,*)'     PRXVR :',PRXVR
        WRITE(6,*)'     PRXVE :',PRXVE
        WRITE(6,*)'     PRXVS :',PRXVS
        WRITE(6,*)'     PRMER :',PRMER
        WRITE(6,*)'     PRMEE :',PRMEE
        WRITE(6,*)'     PRMES :',PRMES
        WRITE(6,*)'     IFGCAL:',IFGCAL
        WRITE(6,*)'     IFXCAL:',IFXCAL
        WRITE(6,*)'     IFMCAL:',IFMCAL
        WRITE(6,*)'     HOP:',HOP
        WRITE(6,*)'     TRACK:',TRACK
        WRITE(6,*)'     ONLY_OVERLAPS:',ONLY_OVERLAPS
        WRITE(6,*)'     IfDCpl:',IfDCpl
        WRITE(6,*)'     IFCURD:',IFCURD
        WRITE(6,*)'     Do_TMOS:',Do_TMOS
        WRITE(6,*)'     Do_SK:',Do_SK
        WRITE(6,*)'     L_Eff:',L_Eff
        WRITE(6,*)'     k-vector:',k_vector
      END IF

C DEFAULT WAVE FUNCTION TYPE:
      WFTYPE='GENERAL '
      IF(IPGLOB.GT.VERBOSE) WRITE(6,*)' ***** INIT ENDS **********'

      CALL QEXIT(ROUTINE)
      RETURN
      END
