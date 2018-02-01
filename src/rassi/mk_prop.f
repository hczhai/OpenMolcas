************************************************************************
* This file is part of OpenMolcas.                                     *
*                                                                      *
* OpenMolcas is free software; you can redistribute it and/or modify   *
* it under the terms of the GNU Lesser General Public License, v. 2.1. *
* OpenMolcas is distributed in the hope that it will be useful, but it *
* is provided "as is" and without any express or implied warranties.   *
* For more details see the full text of the license in the file        *
* LICENSE or in <http://www.gnu.org/licenses/>.                        *
*                                                                      *
* Copyright (C) 2015, Roland Lindh                                     *
************************************************************************
      SUBROUTINE MK_PROP(PROP,IPROP,ISTATE,JSTATE,LABEL,ITYPE,
     &                   BUFF,NBUFF,DENS,NDENS,MASK,ISY12,IOFF)
      IMPLICIT REAL*8 (A-H,O-Z)
***********************************************************************
*     Objective: to compute the transition property between state     *
*                ISTATE and JSTATE of property IPROP.                 *
*                                                                     *
*     This routine will be generalized to a direct routine later.     *
*                                                                     *
*     Author: Roland Lindh, Uppsala University, 23 Dec. 2015          *
***********************************************************************
#include "Molcas.fh"
#include "cntrl.fh"
#include "rassi.fh"
#include "symmul.fh"
      CHARACTER*8 LABEL
      REAL*8 PROP(NSTATE,NSTATE,NPROP), BUFF(NBUFF), DENS(NDENS,4)
      INTEGER IOFF(8)
*
*     Write (*,*) 'MK_PROP:',LABEL,ITYPE
*     Write (*,*) 'IOFF=',IOFF
*     Write (*,*) 'MASK,ISY12=',MASK,ISY12
*     IF (LABEL(1:4).EQ.'TMOS') THEN
*        PORIG(1,IPROP)=0.0D0
*        PORIG(2,IPROP)=0.0D0
*        PORIG(3,IPROP)=0.0D0
*        PNUC(IPROP)=0.0D0
*        PROP(JSTATE,ISTATE,IPROP)=0.0D0
*        IPUSED(IPROP)=1
*        GO TO 300 ! Temporary
*     END IF
*     Write (*,*) 'DENS1=',DDOT_(NDENS,DENS(1,1),1,DENS(1,1),1),
*    &                     DDOT_(NDENS,1.0D0,0,DENS(1,1),1)
*     Write (*,*) 'DENS2=',DDOT_(NDENS,DENS(1,2),1,DENS(1,2),1),
*    &                     DDOT_(NDENS,1.0D0,0,DENS(1,2),1)
*     Write (*,*) 'DENS3=',DDOT_(NDENS,DENS(1,3),1,DENS(1,3),1),
*    &                     DDOT_(NDENS,1.0D0,0,DENS(1,3),1)
*     Write (*,*) 'DENS4=',DDOT_(NDENS,DENS(1,4),1,DENS(1,4),1),
*    &                     DDOT_(NDENS,1.0D0,0,DENS(1,4),1)
      If (LABEL(1:5).eq.'TMOS0' .OR.
     &    LABEL(1:5).eq.'TMOS2') Then
         IC=1
      Else
         IC=ICOMP(IPROP)
      END IF
      IOPT=1
      CALL iRDONE(IRC,IOPT,LABEL,IC,NSIZ,ISCHK)
      IF(MOD(ISCHK/MASK,2).EQ.0) GOTO 300
      IOPT=0
      CALL RDONE(IRC,IOPT,LABEL,IC,BUFF,ISCHK)
*     Write (*,*) 'NBUFF,NSIZ=',NBUFF,NSIZ
*     Write (*,*) 'Int=',DDOT_(NSIZ,BUFF,1,BUFF,1),
*    &                   DDOT_(NSIZ,1.0D0,0,BUFF,1)
      IF ( IRC.NE.0.AND.LABEL(1:4).NE.'TMOS' ) THEN
         WRITE(6,*)
         WRITE(6,'(6X,A)')'*** ERROR IN SUBROUTINE MK_PROP ***'
         WRITE(6,'(6X,A)')'  FAILED IN READING FROM  ONEINT'
         WRITE(6,'(6X,A,A)')'  LABEL     = ',LABEL
         WRITE(6,'(6X,A,I2)')'  COMPONENT = ',IC
         WRITE(6,*)
         GO TO 300
      END IF
      IPUSED(IPROP)=1
C IF THIS IS THE FIRST CALL TO THE SUBROUTINE, PICK UP SOME DATA:
*       IF(ICALL.EQ.0) THEN
C-SVC: for safety reasons, always pick up the data, since it is not
C      necessarily done on the first call!
C PICK UP THE ORIGIN COORDINATES:
      PORIG(1,IPROP)=BUFF(NSIZ+1)
      PORIG(2,IPROP)=BUFF(NSIZ+2)
      PORIG(3,IPROP)=BUFF(NSIZ+3)
C PICK UP THE NUCLEAR CONTRIBUTION FROM INTEGRAL BUFFER
      IF (PNAME(IPROP)(1:3).NE.'ASD') THEN
         PNUC(IPROP)=BUFF(NSIZ+4)
      ELSE
         Write(6,*) "Removing nuclear contrib from ASD: "
      END IF
      IINT=1
      PSUM=0.0D00
      DO 220 ISY1=1,NSYM
         NB1=NBASF(ISY1)
         IF(NB1.EQ.0) GOTO  220
         DO 210 ISY2=1,ISY1
            I12=MUL(ISY1,ISY2)
            IF(IAND(2**(I12-1),ISCHK).EQ.0) GOTO 210
            NB2=NBASF(ISY2)
            IF(NB2.EQ.0) GOTO  210
            NB12=NB1*NB2
            IF(ISY1.EQ.ISY2) NB12=(NB12+NB1)/2
            IF (I12.EQ.ISY12) THEN
               IPOS=IOFF(ISY1)+1
               PSUM=PSUM+DDOT_(NB12,BUFF(IINT),1,DENS(IPOS,ITYPE),1)
            END IF
            IINT=IINT+NB12
210      CONTINUE
220   CONTINUE
C     Write (*,*) 'PSUM=',PSUM,LABEL,IC
C IN THE CASE OF MULTIPOLES, CHANGE SIGN TO ACCOUNT FOR THE NEGATIVE
C ELECTRONIC CHARGE AS COMPARED TO THE NUCLEAR CONTRIBUTION.
      IF(LABEL(1:5).EQ.'MLTPL') PSUM=-PSUM
C In the case of AMFI integrals, they should be multiplied by 2.
C The reason for the factor of two is that this program uses spin
C (uses Clebsch-Gordan coefficients to define Wigner-Eckart
C  reduced matrix elements of spin-tensor properties)
C while the AMFI authors used Pauli matrices.
      IF(LABEL(1:4).EQ.'AMFI') PSUM=2.0D0*PSUM
      PROP(ISTATE,JSTATE,IPROP)=PSUM
      IF (ITYPE.EQ.1.OR.ITYPE.EQ.3) THEN
         PROP(JSTATE,ISTATE,IPROP)=PSUM
      ELSE
         PROP(JSTATE,ISTATE,IPROP)=-PSUM
      END IF
*
300   CONTINUE
*
      RETURN
      END
