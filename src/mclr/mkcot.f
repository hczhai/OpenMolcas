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
      SUBROUTINE MKCOT
     &           (NSYM,NLEV,NVERT,MIDLEV,NMIDV,MIDV1,MIDV2,NWALK,NIPWLK,
     &            ISM,IDOWN,NOW,IOW,NCSF,IOCSF,NOCSF,ISCR,IPRINT)
C
C     PURPOSE: SET UP COUNTER AND OFFSET TABLES FOR WALKS AND CSFS
C     NOTE:    TO GET GET VARIOUS COUNTER AND OFFSET TABLES
C              THE DOWN-CHAIN TABLE IS SCANNED TO PRODUCE ALL POSSIBLE
C              WALKS. POSSIBLY, THERE ARE MORE EFFICIENNET WAYS, BUT
C              SINCE ONLY UPPER AND LOWER WALKS ARE REQUIRED
C              THERE NUMBER IS VERY LIMITTED, EVEN FOR LARGE CASES.
C
      IMPLICIT REAL*8 (A-H,O-Z)
C
      DIMENSION ISM(NLEV),IDOWN(NVERT,0:3)
      DIMENSION NOW(2,NSYM,NMIDV),IOW(2,NSYM,NMIDV)
      DIMENSION NOCSF(NSYM,NMIDV,NSYM),IOCSF(NSYM,NMIDV,NSYM)
      DIMENSION ISCR(3,0:NLEV)
      DIMENSION NCSF(NSYM)
      PARAMETER(IVERT=1,ISYM=2,ISTEP=3)
C
C
C     CLEAR ARRAYS IOW AND NOW
C
      DO 10 IHALF=1,2
        DO 10 MV=1,NMIDV
          DO 10 IS=1,NSYM
            NOW(IHALF,IS,MV)=0
            IOW(IHALF,IS,MV)=0
10    CONTINUE
C
C     CLEAR ARRAYS IOCSF AND NOCSF
C
      DO 20 IS=1,NSYM
        DO 20 MV=1,NMIDV
          DO 20 JS=1,NSYM
            IOCSF(JS,MV,IS)=0
            NOCSF(JS,MV,IS)=0
20    CONTINUE
C
C     START MAIN LOOP OVER UPPER AND LOWER WALKS, RESPECTIVELY.
C
      DO 500 IHALF=1,2
        IF(IHALF.EQ.1) THEN
          IVTSTA=1
          IVTEND=1
          LEV1=NLEV
          LEV2=MIDLEV
        ELSE
          IVTSTA=MIDV1
          IVTEND=MIDV2
          LEV1=MIDLEV
          LEV2=0
        END IF
C
C     LOOP OVER VERTICES STARTING AT TOP OF SUBGRAPH
C
        DO 400 IVTOP=IVTSTA,IVTEND
C     SET CURRENT LEVEL=TOP LEVEL OF SUBGRAPH
          LEV=LEV1
          ISCR(IVERT,LEV)=IVTOP
          ISCR(ISYM,LEV)=1
          ISCR(ISTEP,LEV)=-1
100       IF(LEV.GT.LEV1) GOTO 400
C     FIND FIRST POSSIBLE UNTRIED ARC DOWN FROM CURRENT VERTEX
          IVT=ISCR(IVERT,LEV)
          DO 110 ISTP=ISCR(ISTEP,LEV)+1,3
            IVB=IDOWN(IVT,ISTP)
            IF(IVB.EQ.0) GOTO 110
            GOTO 200
110       CONTINUE
C     NO SUCH ARC WAS POSSIBLE. GO UP ONE STEP AND TRY AGAIN.
          ISCR(ISTEP,LEV)=-1
          LEV=LEV+1
          GOTO 100
C     SUCH AN ARC WAS FOUND. WALK DOWN:
200       ISCR(ISTEP,LEV)=ISTP
          ISML=1
          IF((ISTP.EQ.1).OR.(ISTP.EQ.2)) ISML=ISM(LEV)
          LEV=LEV-1
          ISCR(ISYM,LEV)=1+IEOR(ISML-1,ISCR(ISYM,LEV+1)-1)
          ISCR(IVERT,LEV)=IVB
          ISCR(ISTEP,LEV)=-1
          IF (LEV.GT.LEV2) GOTO 100
C     WE HAVE REACHED THE BOTTOM LEVEL. THE WALK IS COMPLETE.
C     FIND MIDVERTEX NUMBER ORDERING NUMBER AND SYMMETRY OF THIS WALK
          MV=ISCR(IVERT,MIDLEV)+1-MIDV1
          IWSYM=ISCR(ISYM,LEV2)
          ILND=1+NOW(IHALF,IWSYM,MV)
C     SAVE THE MAX WALK NUMBER FOR GIVEN SYMMETRY AND MIDVERTEX
          NOW(IHALF,IWSYM,MV)=ILND
C     BACK UP ONE LEVEL AND TRY AGAIN:
          LEV=LEV+1
          GOTO 100
400     CONTINUE
500   CONTINUE
C
C     NOW,CONSTRUCT OFFSET TABLES FOR UPPER AND LOWER WALKS
C     SEPARATED FOR EACH MIDVERTEX AND SYMMETRY
C
      NUW=0
      DO 251 MV=1,NMIDV
        DO 252 IS=1,NSYM
          IOW(1,IS,MV)=NUW*NIPWLK
          NUW=NUW+NOW(1,IS,MV)
252     CONTINUE
251   CONTINUE
      NWALK=NUW
      DO 253 MV=1,NMIDV
        DO 254 IS=1,NSYM
          IOW(2,IS,MV)=NWALK*NIPWLK
          NWALK=NWALK+NOW(2,IS,MV)
254     CONTINUE
253   CONTINUE
      NLW=NWALK-NUW
C
C     FINALLY, CONSTRUCT COUNTER AND OFFSET TABLES FOR THE CSFS
C     SEPARATED BY MIDVERTICES AND SYMMETRY.
C     FORM ALSO CONTRACTED SUMS OVER MIDVERTICES.
C
      DO 271 ISYTOT=1,NSYM
        NCSF(ISYTOT)=0
        DO 272 MV=1,NMIDV
          DO 273 ISYUP=1,NSYM
            ISYDWN=1+IEOR(ISYTOT-1,ISYUP-1)
            N=NOW(1,ISYUP,MV)*NOW(2,ISYDWN,MV)
            NOCSF(ISYUP,MV,ISYTOT)=N
            IOCSF(ISYUP,MV,ISYTOT)=NCSF(ISYTOT)
            NCSF(ISYTOT)=NCSF(ISYTOT)+N
273       CONTINUE
272     CONTINUE
271   CONTINUE
      IF (IPRINT.GE.5) THEN
        WRITE(6,*)
        WRITE(6,*)' TOTAL NR OF WALKS: UPPER ',NUW
        WRITE(6,*)'                    LOWER ',NLW
        WRITE(6,*)'                     SUM  ',NWALK
        WRITE(6,*)
        WRITE(6,*)' NR OF CONFIGURATIONS/SYMM:'
        WRITE(6,'(8(1X,I8))')(NCSF(IS),IS=1,NSYM)
        WRITE(6,*)
        WRITE(6,*)
        WRITE(6,*)' NR OF WALKS AND CONFIGURATIONS IN NRCOUP'
        WRITE(6,*)' BY MIDVERTEX AND SYMMETRY.'
        DO 310 MV=1,NMIDV
          WRITE(6,*)
          WRITE(6,1234) MV,(NOW(1,IS,MV),IS=1,NSYM)
          WRITE(6,1235)    (NOW(2,IS,MV),IS=1,NSYM)
          DO 305 IST=1,NSYM
            WRITE(6,1236)IST,(NOCSF(IS,MV,IST),IS=1,NSYM)
305       CONTINUE
1234  FORMAT('  MV=',I2,'    UPPER WALKS:',8I6)
1235  FORMAT('           LOWER WALKS:',8I6)
1236  FORMAT(' IST=',I2,'  CONFIGURATIONS:',8I6)
310     CONTINUE
        WRITE(6,*)' OFFSETS IN NRCOUP'
        WRITE(6,*)' BY MIDVERTEX AND SYMMETRY.'
        DO 377 MV=1,NMIDV
          WRITE(6,*)
          WRITE(6,1234) MV,(IOW(1,IS,MV),IS=1,NSYM)
          WRITE(6,1235)    (IOW(2,IS,MV),IS=1,NSYM)
377     CONTINUE
      ENDIF
C
C
C     EXIT
C
      RETURN
      END
