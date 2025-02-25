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
      SUBROUTINE READIN_RASSI

#ifdef _DMRG_
      use qcmaquis_interface_cfg
!       use qcmaquis_interface_environment, only:
!      &    read_dmrg_info
#endif

      IMPLICIT NONE
#include "prgm.fh"
      CHARACTER*16 ROUTINE
      PARAMETER (ROUTINE='READIN')
#include "rasdim.fh"
#include "rassi.fh"
#include "cntrl.fh"
#include "jobin.fh"
#include "WrkSpc.fh"
      CHARACTER*80 LINE
      INTEGER MXPLST
      PARAMETER (MXPLST=50)
      CHARACTER*8 TRYNAME
      Integer ALGO,Nscreen
      Real*8  dmpk, tmp
      Logical timings, Estimate, Update, Deco, PseudoChoMOs
      Logical lExists
      Common /CHORASSI / ALGO,Nscreen,dmpk
      COMMON /CHOTIME / timings
      COMMON /LKSCREEN / Estimate, Update, Deco, PseudoChoMOs
      Integer I, J, ISTATE, JSTATE, IJOB, ILINE, LINENR
      Integer LuIn
      Integer NFLS
#ifdef _DMRG_
      CHARACTER*16 dmrgchkp
#endif
      REAL*8 ANORM

      CALL QENTER(ROUTINE)

      Call SpoolInp(LuIn)

C --- Default settings for Cholesky
      Algo = 2
      Nscreen = 10
      dmpk = 1.0d-1
      timings = .false.
      Estimate = .false.
      Update = .true.
      Deco = .true.
      PseudoChoMOs = .false.
#if defined (_MOLCAS_MPP_)
      ChFracMem=0.3d0
#else
      ChFracMem=0.0d0
#endif

      !> set some defaults
      QDPT2SC = .false.
      QDPT2EV = .true.

C Find beginning of input:
 50   Read(LuIn,'(A72)',END=998) LINE
      CALL NORMAL(LINE)
      IF(LINE(1:7).NE.'&RASSI ') GOTO 50
      LINENR=0
100   Read(LuIn,'(A72)',END=998) LINE
      LINENR=LINENR+1
      CALL NORMAL(LINE)
      IF(LINE(1:1).EQ.'*') GOTO 100
      IF(LINE.EQ.' ') GOTO 100
      IF (LINE(1:4).EQ.'END ') GOTO 200
C ------------------------------------------
      IF (LINE(1:4).EQ.'TEST') THEN
        PRSXY=.TRUE.
        PRORB=.TRUE.
        PRTRA=.TRUE.
        PRCI=.TRUE.
        GOTO 100
      END IF
C ------------------------------------------
      IF (LINE(1:4).EQ.'BINA') THEN
        BINA=.TRUE.
        NATO=.TRUE.
        Read(LuIn,*,ERR=997) NBINA
        LINENR=LINENR+1
        Read(LuIn,*,ERR=997) (IBINA(1,I),IBINA(2,I),I=1,NBINA)
        GOTO 100
      END IF
C ------------------------------------------
      IF (LINE(1:4).EQ.'EXTR') THEN
        IF(IPGLOB.GT.SILENT) THEN
         Call WarningMessage(1,'Obsolete EXTRACT keyword used.')
         WRITE(6,*)' Please remove it from the input.'
        END IF
        GOTO 100
      END IF
C ------------------------------------------
      IF (LINE(1:4).EQ.'NATO') THEN
        NATO=.TRUE.
        Read(LuIn,*,ERR=997) NRNATO
        LINENR=LINENR+1
        GOTO 100
      END IF
C-------------------------------------------
CTL2004-start
C-------------------------------------------
      IF (LINE(1:4).EQ.'NONA') THEN
         NONA=.TRUE.
        Read(LuIn,*,ERR=997)NONA_ISTATE, NONA_JSTATE
        LINENR=LINENR+1
        GOTO 100
      END IF
C-------------------------------------------
CTL2004-end
C-------------------------------------------
      IF(LINE(1:4).EQ.'RFPE') THEN
        RFPERT=.TRUE.
        GOTO 100
      END IF
C -- FA 2005 start--------------------------
C-------------------------------------------
C --- Cholesky with default settings
      IF(LINE(1:4).EQ.'CHOL') THEN
        Call Cho_rassi_rdInp(.true.,LuIn)
        GOTO 100
      END IF
C --- Cholesky with customized settings
      IF(LINE(1:4).EQ.'CHOI') THEN
        Call Cho_rassi_rdInp(.False.,LuIn)
        GOTO 100
      END IF
C -- FA 2005 end----------------------------
      IF(LINE(1:4).EQ.'SOPR') THEN
        Read(LuIn,*,ERR=997) NSOPR,(SOPRNM(I),ISOCMP(I),
     &                            I=1,MIN(MXPROP,NSOPR))
        LINENR=LINENR+1
        DO I=1,MIN(MXPROP,NSOPR)
          CALL UPCASE(SOPRNM(I))
          If(SOPRNM(I)(1:5).EQ.'MLTPL') THEN
            IF(SOPRNM(I)(7:8).EQ.'  ') THEN
              SOPRNM(I)='MLTPL  '//SOPRNM(I)(6:6)
            ELSE IF(SOPRNM(I)(8:8).EQ.' ') THEN
              SOPRNM(I)='MLTPL '//SOPRNM(I)(6:7)
            END IF
          END IF
        END DO
        GOTO 100
      END IF
C ------------------------------------------
      IF(LINE(1:4).EQ.'PROP') THEN
        Read(LuIn,*,ERR=997) NPROP,(PNAME(I),ICOMP(I),
     &                            I=1,MIN(MXPROP,NPROP))
        LINENR=LINENR+1
        DO I=1,MIN(MXPROP,NPROP)
          CALL UPCASE(PNAME(I))
          If(PNAME(I)(1:5).EQ.'MLTPL') THEN
            IF(PNAME(I)(7:8).EQ.'  ') THEN
              PNAME(I)='MLTPL  '//PNAME(I)(6:6)
            ELSE IF(PNAME(I)(8:8).EQ.' ') THEN
              PNAME(I)='MLTPL '//PNAME(I)(6:7)
            END IF
          END IF
        END DO
        GOTO 100
      END IF
C ------------------------------------------
      IF (LINE(1:4).EQ.'OVER') THEN
        PRSXY=.TRUE.
        GOTO 100
      END IF
C ------------------------------------------
      IF (LINE(1:4).EQ.'TRDI') THEN
* Print transition dipole vectors
        PRDIPVEC=.TRUE.
        GOTO 100
      END IF
C ------------------------------------------
      IF (LINE(1:4).EQ.'TDMN') THEN
* Print transition dipole vectors
        PRDIPVEC=.TRUE.
        Read(LuIn,*,ERR=997) TDIPMIN
        GOTO 100
      END IF
C ------------------------------------------
      IF (LINE(1:4).EQ.'ORBI') THEN
        PRORB=.TRUE.
        GOTO 100
      END IF
C ------------------------------------------
      IF (LINE(1:4).EQ.'CIPR') THEN
        PRCI=.TRUE.
        GOTO 100
      END IF
C ------------------------------------------
      IF(LINE(1:4).EQ.'THRS')THEN
        Read(LuIn,*,ERR=997) CITHR
        LINENR=LINENR+1
        GOTO 100
      END IF
C ------------------------------------------
      IF(LINE(1:4).EQ.'ONEL') THEN
        IFHAM=.FALSE.
        GOTO 100
      END IF
C ------------------------------------------
      IF(LINE(1:4).EQ.'ONEE') THEN
        IFHAM=.FALSE.
        GOTO 100
      END IF
C ------------------------------------------
      IF(LINE(1:4).EQ.'SPIN') THEN
        IFSO=.TRUE.
        GOTO 100
      END IF
C ------------------------------------------
* PAM07 Added: Keyword for printing spin-orbit coupling matrix elements
* A threshold in reciprocal cm is entered.
      IF(LINE(1:4).EQ.'SOCO') THEN
        Read(LuIn,*,ERR=997) SOTHR_PRT
        LINENR=LINENR+1
        IF(SOTHR_PRT.LT.0.0D0) SOTHR_PRT=0.0D0
        NSOTHR_PRT=10000
        GOTO 100
      END IF
C ------------------------------------------
      IF(LINE(1:4).EQ.'NROF'.or.LINE(1:4).EQ.'NR O') THEN
        NSTATE=0
        Read(LuIn,*,ERR=997) NJOB,TRYNAME
        CALL UpCase(TRYNAME)
        IF(TRYNAME.EQ.'ALL') THEN
          LINENR=LINENR+1
        ELSE
          BACKSPACE(LuIn)
          Read(LuIn,*,ERR=997) NJOB,(NSTAT(I),I=1,NJOB)
          DO IJOB=1,NJOB
            NSTATE=NSTATE+NSTAT(IJOB)
          END DO
          Call GetMem('JBNUM','Allo','Inte',LJBNUM,NSTATE)
          Call GetMem('LROOT','Allo','Inte',LLROOT,NSTATE)
          LINENR=LINENR+1
          NSTATE=0
          DO IJOB=1,NJOB
            ISTAT(IJOB)=NSTATE+1
            Read(LuIn,*,ERR=997) (iWork(lLROOT+NSTATE+J),
     &                                 J=0,NSTAT(IJOB)-1)
            LINENR=LINENR+1
            DO ISTATE=NSTATE+1,NSTATE+NSTAT(IJOB)
              iWork(lJBNUM+ISTATE-1)=IJOB
            END DO
            NSTATE=NSTATE+NSTAT(IJOB)
          END DO
        END IF
        GOTO 100
      END IF
C ------------------------------------------
      IF(LINE(1:4).EQ.'IPHN') THEN
*        Read(LuIn,'(9(A7,1X))',ERR=997)(JBNAME(I),I=1,NJOB)
*        LINENR=LINENR+1
        DO I=1,NJOB
         READ(LuIn,*,ERR=997) JBNAME(I)
         LINENR=LINENR+1
         CALL UpCase(JBNAME(I))
        END DO
        GOTO 100
      END IF
C ------------------------------------------
      IF(LINE(1:4).EQ.'FILE') THEN
        READ(LuIn,*,ERR=997) NJOB
        LINENR=LINENR+1
        DO I=1,NJOB
         READ(LuIn,*,ERR=997) LINE
         LINENR=LINENR+1
         CALL FILEORB(LINE,JBNAME(I))
        END DO
        GOTO 100
      END IF
C ------------------------------------------
      IF(LINE(1:4).EQ.'HEXT') THEN
        IFHEXT=.TRUE.
        IFHAM =.TRUE.
        Call GetMem('HAM','Allo','Real',LHAM,NSTATE**2)
        Read(LuIn,*,ERR=997)((WORK(LHAM+ISTATE*NSTATE+JSTATE),
     &                                           JSTATE=0,ISTATE),
     &                                           ISTATE=0,NSTATE-1)
        DO ISTATE=0,NSTATE-2
         DO JSTATE=ISTATE,NSTATE-1
           WORK(LHAM+JSTATE*NSTATE+ISTATE)=
     &     WORK(LHAM+ISTATE*NSTATE+JSTATE)
         END DO
        END DO
        LINENR=LINENR+NSTATE
        GOTO 100
      END IF
C ------------------------------------------
      IF(LINE(1:4).EQ.'HEFF') THEN
        IFHEFF=.TRUE.
        IFHAM =.TRUE.
        GOTO 100
      END IF
C ------------------------------------------
      IF(LINE(1:4).EQ.'HCOM') THEN
        IFHCOM=.TRUE.
        IFHAM =.TRUE.
        GOTO 100
      END IF
C ------------------------------------------
      IF(LINE(1:4).EQ.'EJOB') THEN
        IFEJOB=.TRUE.
        IFHAM=.TRUE.
!   Leon: Is it really needed?
!        LINENR=LINENR+1
        GOTO 100
      END IF
C ------------------------------------------
      IF(LINE(1:4).EQ.'HDIA') THEN
        IFHDIA=.TRUE.
        Call GetMem('HDIAG','ALLO','REAL',LHDIAG,NSTATE)
        Read(LuIn,*,ERR=997)(Work(LHDIAG+ISTATE),ISTATE=0,NSTATE-1)
        LINENR=LINENR+1
        GOTO 100
      END IF
C ------------------------------------------
      IF(LINE(1:4).EQ.'SHIF') THEN
        IFSHFT=.TRUE.
        Call GetMem('ESHFT','Allo','Real',LESHFT,NSTATE)
        Read(LuIn,*,ERR=997)(Work(LESHFT+ISTATE),ISTATE=0,NSTATE-1)
        LINENR=LINENR+1
        GOTO 100
      END IF
C--------------------------------------------
      If(Line(1:4).eq.'TOFI') then
        ToFile=.true.
        Linenr=Linenr+1
        GoTo 100
      Endif
C--------------------------------------------
      If(Line(1:4).eq.'J-VA') then
        IFJ2=1
        Linenr=Linenr+1
        GoTo 100
      Endif
C--------------------------------------------
      If(Line(1:4).eq.'OMEG') then
        IFJZ=1
        Linenr=Linenr+1
        GoTo 100
      Endif
C-SVC 2007-----------------------------------
      If(Line(1:4).eq.'EPRG') then
        IFGCAL=.TRUE.
        Read(LuIn,*,ERR=997) EPRTHR
        IF (EPRTHR .LT. 0.0D0) EPRTHR=0.0D0
        Linenr=Linenr+1
        GoTo 100
      Endif



c BP - Hyperfine calculations
      If(Line(1:4).eq.'EPRA') then
      !write(6,*)"EPRA read"
        IFACAL=.TRUE.
        Linenr=Linenr+1
        GoTo 100
      Endif
      If(Line(1:4).eq.'AFCO') then
      !write(6,*)"AFCO read"
        IFACALSD=.FALSE.
        Linenr=Linenr+1
        GoTo 100
      Endif
      If(Line(1:4).eq.'ASDO') then
      !write(6,*)"ASDO read"
        IFACALFC=.FALSE.
        Linenr=Linenr+1
        GoTo 100
      Endif
c Kamal Sharkas beg - PSO Hyperfine calculations
      If(Line(1:4).eq.'AFCC') then
        IFACALFCON=.TRUE.
        Linenr=Linenr+1
        GoTo 100
      Endif

      If(Line(1:4).eq.'ASDC') then
        IFACALSDON=.TRUE.
        Linenr=Linenr+1
        GoTo 100
      Endif

      If(Line(1:4).eq.'FCSD') then
        IFACALFCSDON=.TRUE.
        Linenr=Linenr+1
        GoTo 100
      Endif

      If(Line(1:4).eq.'APSO') then
        IFACALPSO=.TRUE.
        Linenr=Linenr+1
        GoTo 100
      Endif

      If(Line(1:4).eq.'GTSA') then
        IFGTCALSA=.TRUE.
        Linenr=Linenr+1
        GoTo 100
      Endif

      If(Line(1:4).eq.'ATSA') then
        IFATCALSA=.TRUE.
        Linenr=Linenr+1
        GoTo 100
      Endif

      If(Line(1:4).eq.'SHMP') then
        IFGTSHSA=.TRUE.
        Read(LuIn,*,ERR=997) MULTIP
        Linenr=Linenr+1
        GoTo 100
      Endif

      If(Line(1:4).eq.'VSUS') then
        IFVANVLECK=.TRUE.
        READ(LuIn,*,err=997) TMINS, TMAXS, NTS
        Linenr=Linenr+1
        GoTo 100
      Endif

      If(Line(1:4).eq.'NMRT') then
        IFSONCINI=.TRUE.
        READ(LuIn,*,err=997) TMINP, TMAXP, NTP
        Linenr=Linenr+1
        GoTo 100
      Endif

      If(Line(1:4).eq.'NMRF') then
        IFSONCIFC=.TRUE.
        READ(LuIn,*,err=997) TMINF, TMAXF, NTF
        Linenr=Linenr+1
        GoTo 100
      Endif

c Kamal Sharkas end - PSO Hyperfine calculations

c BP Natural orbitals options
      If(Line(1:4).eq.'SONO') then
        Read(LuIn,*,ERR=997) SONATNSTATE
        CALL GETMEM('SONATS','ALLO','INTE',LSONAT,SONATNSTATE)
        Linenr=Linenr+1
        DO ILINE=1,SONATNSTATE
          Read(LuIn,*,ERR=997) IWORK(LSONAT-1+ILINE)
          Linenr=Linenr+1
        END DO
        GoTo 100
      Endif
      If(Line(1:4).eq.'SODI') then
        Read(LuIn,*,ERR=997) SODIAGNSTATE
        CALL GETMEM('SODIAG','ALLO','INTE',LSODIAG,SODIAGNSTATE)
        Linenr=Linenr+1
        DO ILINE=1,SODIAGNSTATE
          Read(LuIn,*,ERR=997) IWORK(LSODIAG-1+ILINE)
          Linenr=Linenr+1
        END DO
        GoTo 100
      Endif
      If(Line(1:4).eq.'NOSO') then
        NOSO=.TRUE.
        Linenr=Linenr+1
        GoTo 100
      Endif
      If(Line(1:4).eq.'CURD') then
        IFCURD=.TRUE.
        Linenr=Linenr+1
        GoTo 100
      Endif
c END BP OPTIONS
C-SVC 2007 2008------------------------------
      If(Line(1:4).eq.'MAGN') then
        IFXCAL=.TRUE.
        READ(LuIn,*,err=997) NBSTEP,BSTART,BINCRE,BANGRES
        READ(LuIn,*,err=997) NTSTEP,TSTART,TINCRE
        IF (BANGRES.GT.0.0D0) THEN
            IFMCAL=.TRUE.
        ENDIF
        Linenr=Linenr+2
        GoTo 100
      EndIf
C--------------------------------------------
      If(Line(1:4).eq.'XVIN') then
        PRXVR=.true.
        Linenr=Linenr+1
        GoTo 100
      Endif
C--------------------------------------------
      If(Line(1:4).eq.'XVES') then
        PRXVE=.true.
        Linenr=Linenr+1
        GoTo 100
      Endif
C--------------------------------------------
      If(Line(1:4).eq.'XVSO') then
        PRXVS=.true.
        Linenr=Linenr+1
        GoTo 100
      Endif
C--------------------------------------------
      If(Line(1:4).eq.'MEIN') then
        PRMER=.true.
        Linenr=Linenr+1
        GoTo 100
      Endif
C--------------------------------------------
      If(Line(1:4).eq.'MEES') then
        PRMEE=.true.
        Linenr=Linenr+1
        GoTo 100
      Endif
C--------------------------------------------
      If(Line(1:4).eq.'MESO') then
        PRMES=.true.
        Linenr=Linenr+1
        GoTo 100
      Endif
C--------------------------------------------
C*****IS 30-09/2007**************************
      IF(Line(1:4).eq.'HOP ') THEN
        HOP=.TRUE.
        LINENR=LINENR+1
        GOTO 100
      ENDIF
C--------------------------------------------
      IF(Line(1:4).eq.'TRAC') THEN
        TRACK=.TRUE.
        IFHAM=.FALSE.
        LINENR=LINENR+1
        GOTO 100
      ENDIF
C--------------------------------------------
      IF(Line(1:4).eq.'STOV') THEN
        ONLY_OVERLAPS=.TRUE.
        IFHAM=.FALSE.
        LINENR=LINENR+1
        GOTO 100
      ENDIF
C--------------------------------------------
      If(Line(1:4).eq.'DCOU') then
        IfDCpl=.True.
        Linenr=Linenr+1
        GoTo 100
      Endif
C--------------------------------------------
C*PAM Nov 2011
      IF(Line(1:4).eq.'TRD1') THEN
        IFTRD1=.TRUE.
        LINENR=LINENR+1
        GOTO 100
      ENDIF
C--------------------------------------------
      IF(Line(1:4).eq.'TRD2') THEN
        IFTRD1=.TRUE.
        IFTRD2=.TRUE.
        LINENR=LINENR+1
        GOTO 100
      ENDIF
C--------------------------------------------
*CEH April 2015
      IF(Line(1:4).eq.'DQVD') THEN
        DQVD=.TRUE.
        LINENR=LINENR+1
        GOTO 100
      ENDIF
C--------------------------------------------
      IF(LINE(1:4).EQ.'ALPH')THEN
        Read(LuIn,*,ERR=997) ALPHZ
        LINENR=LINENR+1
        GOTO 100
      END IF
C ------------------------------------------
      IF(LINE(1:4).EQ.'BETA')THEN
        Read(LuIn,*,ERR=997) BETAE
        LINENR=LINENR+1
        GOTO 100
      END IF
C--------------------------------------------
*LKS Sep 2015
      IF(Line(1:4).eq.'DIPR') THEN
! Printing threshold for dipole intensities. Current default 1.0D-5
        DIPR=.TRUE.
        Read(LuIn,*,ERR=997) OSTHR_DIPR
        LINENR=LINENR+1
        GOTO 100
      ENDIF
C--------------------------------------------
      IF(LINE(1:4).EQ.'QIPR')THEN
! Printing threshold for quadrupole intensities. Current default 1.0D-8
        QIPR=.TRUE.
        Read(LuIn,*,ERR=997) OSTHR_QIPR
        LINENR=LINENR+1
        GOTO 100
      END IF
C ------------------------------------------
      IF(LINE(1:4).EQ.'QIAL')THEN
! Print all contributions for quadrupole intensities.
        QIALL=.TRUE.
        LINENR=LINENR+1
        GOTO 100
      END IF
C ------------------------------------------
      If(Line(1:4).eq.'TMOS') then
! Calculate exact isotropically averaged semi-classical intensities
! Activate integration of transition moment oscillator strengths
! based on the exact non-relativistic Hamiltonian in the weak field
! approximation.
        Do_TMOS=.TRUE.
        ToFile=.TRUE.
        Linenr=Linenr+1
        GoTo 100
      Endif
C--------------------------------------------
#ifdef _DMRG_
      ! Leon 22/11/2016 -- Moved DMRG initialisation here
      ! Introduced a mandatory keyword for DMRG
      IF (Line(1:4).eq.'DMRG') then
      ! Leon 29/11/2016 -- Ignore the dmrg_interface.parameters file
      ! since different JobIPHs/checkpoint files may come from different
      ! calculations. The parameters that should be otherwise read in
      ! read_dmrg_info() will be read in rdjob, if we need them
        doDMRG = .true.
      ! check whether we should NOT read checkpoint names from xxx.h5 files
        Read(LuIn,*,ERR=997) dmrgchkp
        call UpCase(dmrgchkp)
        if (dmrgchkp(1:5).eq.'NOCH') then
          doMPSSICheckpoints = .false.
          LINENR=LINENR+1
        else
          doMPSSICheckpoints = .true.
          BACKSPACE(LuIn)
        end if
        GOTO 100
      End IF
C--------------------------------------------
      if (Line(1:4).eq.'QDSC') then
        QDPT2SC = .true.
        goto 100
      end if
C--------------------------------------------
      if (Line(1:4).eq.'NOQD') then
        QDPT2EV = .false.
        goto 100
      end if
#endif
C--------------------------------------------
      IF(LINE(1:4).EQ.'KVEC')THEN
! Calculate exact semi-classical intensities in given directions
        DO_KVEC=.TRUE.
        PRRAW=.TRUE.
        Do_TMOS=.TRUE.
        ToFile=.TRUE.
        Read(LuIn,*,ERR=997) NKVEC
        CALL GETMEM('KVEC  ','ALLO','REAL',PKVEC,3*NKVEC)
        Linenr=Linenr+1
        DO ILINE=1,NKVEC
          Read(LuIn,*,ERR=997) (WORK(PKVEC+ILINE-1+(I-1)*NKVEC),I=1,3)
          Linenr=Linenr+1
        END DO
! Ensure that the wavectors are normalized
        DO ILINE=1,NKVEC
          ANORM = WORK(PKVEC+ILINE-1)**2 +
     &            WORK(PKVEC+ILINE-1+NKVEC)**2 +
     &            WORK(PKVEC+ILINE-1+2*NKVEC)**2
          WORK(PKVEC+ILINE-1) =
     &    WORK(PKVEC+ILINE-1)/DSQRT(ANORM)
          WORK(PKVEC+ILINE-1+NKVEC) =
     &    WORK(PKVEC+ILINE-1+NKVEC)/DSQRT(ANORM)
          WORK(PKVEC+ILINE-1+2*NKVEC) =
     &    WORK(PKVEC+ILINE-1+2*NKVEC)/DSQRT(ANORM)
        END DO
        GOTO 100
      END IF
C--------------------------------------------
      IF(LINE(1:4).EQ.'PRRA')THEN
! Print the raw directions for exact semi-classical intensities
        PRRAW=.TRUE.
        LINENR=LINENR+1
        GOTO 100
      END IF
C ------------------------------------------
      IF(LINE(1:4).EQ.'PRWE')THEN
! Print the weighted directions for exact semi-classical intensities
        PRWEIGHT=.TRUE.
        LINENR=LINENR+1
        GOTO 100
      END IF
C ------------------------------------------
      IF(LINE(1:4).EQ.'TOLE')THEN
! Set tolerance for different gauges - currently 10 percent (0.1D0)
! Defined as Tolerance = ABS(1-O_r/O_p)
        NEW_TOLERANCE=.TRUE.
        Read(LuIn,*,ERR=997) TOLERANCE
        LINENR=LINENR+1
        GOTO 100
      END IF
C ------------------------------------------
      IF(LINE(1:4).EQ.'REDL')THEN
! Reduce looping in intensities. Set limit for the inner and outer loop
        REDUCELOOP=.TRUE.
        Read(LuIn,*,ERR=997) LOOPDIVIDE
        LINENR=LINENR+1
        GOTO 100
      END IF
C ------------------------------------------
      If(Line(1:4).eq.'L-EF') then
! Set the order of the Lebedev polynomials used for the numerical
! integration over solid angles. Current default 5.
        Read(LuIn,*,ERR=997) L_Eff
        Linenr=Linenr+1
        GoTo 100
      Endif
C--------------------------------------------
      If(Line(1:4).eq.'K-VE') then
! Set a specific direction of the incident light when computing
! the transition moment and oscillator stength in the use of
! the vector field (A) in the non-relativistic Hamiltonian.
        Do_SK=.TRUE.
        Read(LuIn,*,ERR=997) (K_Vector(i),i=1,3)
        Linenr=Linenr+1
        tmp=K_Vector(1)**2+k_Vector(2)**2+k_Vector(3)**2
        tmp = 1.0D0/Sqrt(tmp)
        k_Vector(1)=k_Vector(1)*tmp
        k_Vector(2)=k_Vector(2)*tmp
        k_Vector(3)=k_Vector(3)*tmp
        GoTo 100
      Endif
C--------------------------------------------
*
      WRITE(6,*)' The following input line was not understood:'
      WRITE(6,'(A)') LINE
      GOTO 999

997   CONTINUE
      Call WarningMessage(2,'Error reading standard input.')
      WRITE(6,*)' RASSI input near line nr.',LINENR+1
      GOTO 999

998   CONTINUE
      Call WarningMessage(2,'I/O error.')
      WRITE(6,*)' READIN: Unexpected end of input file.'

999   CONTINUE
      CALL XFLUSH(6)
      CALL ABEND()

200   CONTINUE
cnf
      If (IfDCpl .and. .not.IfHam) Then
         Call WarningMessage(1,'Input request was ignored.')
         Write(6,*) ' Cannot compute the approximate derivative',
     &              ' coupling terms without the energies.'
         Write(6,*) ' Ignore them.'
         IfDCpl = .False.
      End If
cnf
* Determine file names, if undefined.
      IF(JBNAME(1).EQ.'UNDEFINE') THEN
* The first (perhaps only) jobiph file is named 'JOB001', or maybe 'JOBIPH'
* when no name has been issued by the user:
        NFLS=0
        TRYNAME='JOB001'
        CALL F_INQUIRE(TRYNAME,LEXISTS)
        IF(LEXISTS) THEN
          NFLS=1
          JBNAME(NFLS)=TRYNAME
        ELSE
          TRYNAME='JOBIPH'
          CALL F_INQUIRE(TRYNAME,LEXISTS)
          IF(LEXISTS) THEN
            NFLS=1
            JBNAME(NFLS)=TRYNAME
          ELSE
            Call WarningMessage(1,'RASSI lacks JobIph files.')
            WRITE(6,*)' RASSI fails: No jobiph files found.'
            CALL ABEND()
          END IF
        END IF
* Subsequent (if any) jobfiles can be named according to old
* or new naming convention.
* Using new standard scheme for default jobiph names?
        DO I=1,MXJOB-1
          IF (NJOB.GT.0.AND.I.GT.NJOB) GOTO 211
          WRITE(TRYNAME,'(A6,I2.2)') 'JOBIPH',I
          CALL F_INQUIRE(TRYNAME,LEXISTS)
          IF(LEXISTS) THEN
            NFLS=NFLS+1
            JBNAME(NFLS)=TRYNAME
          ELSE
            GOTO 211
          END IF
        END DO
        Call WarningMessage(1,'RASSI fails to identify JobIph files.')
        WRITE(6,*)' Too many jobiph files in this directory.'
        CALL ABEND()
 211    CONTINUE
        IF(NFLS.EQ.1) THEN
* We may be using old standard scheme for default jobiph names?
          DO I=1,MXJOB-1
            IF (NJOB.GT.0.AND.I.GT.NJOB) GOTO 212
            WRITE(TRYNAME,'(A3,I3.3)') 'JOB',I+1
            CALL F_INQUIRE(TRYNAME,LEXISTS)
            IF(LEXISTS) THEN
              NFLS=NFLS+1
              JBNAME(NFLS)=TRYNAME
            ELSE
              GOTO 212
            END IF
           END DO
           Call WarningMessage(1,
     &       'RASSI fails to identify JobIph files.')
           WRITE(6,*)' Too many jobiph files in this directory.'
           CALL ABEND()
 212       CONTINUE
           IF(NFLS.GT.1) THEN
* Then we are definitely using the old default file name convention.
           END IF
        END IF
        IF(NJOB.GT.0) THEN
* Input has been given for NJOB, etc., and will be used.
          IF(NFLS.LT.NJOB) THEN
            Call WarningMessage(1,'RASSI found too few JobIph files.')
            CALL ABEND()
          END IF
        ELSE
* Use defaults.
          NJOB=NFLS
        END IF
      END IF

      CALL XFLUSH(6)

      Call Close_LuSpool(LuIn)

      CALL QEXIT(ROUTINE)
      RETURN
      END
