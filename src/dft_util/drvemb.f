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
* Copyright (C) 2010,2012, Francesco Aquilante                         *
************************************************************************
      Subroutine DrvEMB(h1,D,RepNuc,nh1,
     &                  KSDFT,ExFac,Do_Grad,Grad,nGrad,
     &                  D1I,D1A,nD1,DFTFOCK)
************************************************************************
************************************************************************
*** Orbital-Free Embedding calculation                               ***
***                                                                  ***
*** Method:                                                          ***
***     T. A. Wesolowski, A. Warshel, J. Phys. Chem. 97 (1993) 8050. ***
***                                                                  ***
*** NDSD potential:                                                  ***
***     J.-M. Garcia Lastra, J. W. Kaminski, T. A. Wesolowski,       ***
***                               J. Chem. Phys.  129 (2008) 074107. ***
***                                                                  ***
*** Embedding multi-determinantal wfs:                               ***
***     T. A. Wesolowski, Phys. Rev.A. 77 (2008) 012504.             ***
***                                                                  ***
***                                                                  ***
*** Embedding Hartree-Fock wf:                                       ***
***     F. Aquilante, T. A. Wesolowski                               ***
***                       J. Chem. Phys. 135 (2011) 084120.          ***
***                                                                  ***
***                                                                  ***
*** Author: F. Aquilante, Geneva July 2010                           ***
***                                                                  ***
***                       (last update: Feb 2012)                    ***
***                                                                  ***
************************************************************************
************************************************************************
      Implicit Real*8 (a-h,o-z)
      External LSDA_emb, Checker
#include "real.fh"
#include "WrkSpc.fh"
#include "debug.fh"
      Real*8 h1(nh1), D(nh1,2), Grad(nGrad)
      Real*8 D1I(nD1),D1A(nD1)
      Logical Do_Grad
      Character*(*) KSDFT
      Character*4 DFTFOCK
      Character*16 NamRfil
      Real*8 Vxc_ref(2)
      Logical Do_OFemb,KEonly,OFE_first
      COMMON  / OFembed_L / Do_OFemb,KEonly,OFE_first
      COMMON  / OFembed_R / Rep_EN,Func_AB,Func_A,Func_B,Energy_NAD,
     &                      V_Nuc_AB,V_Nuc_BA,V_emb
      COMMON  / OFembed_R1/ Xsigma
      COMMON  / OFembed_R2/ dFMD
      COMMON  / OFembed_I / ipFMaux, ip_NDSD, l_NDSD
*
      Real*8 Xlambda
      External Xlambda
      Debug=.False.
*                                                                      *
************************************************************************
*                                                                      *
      Call QEnter('DrvEMB')
      Call Setup_iSD()
      If (Do_Grad) Call FZero(Grad,nGrad)
************************************************************************
*                                                                      *
*     Setup of density matrices for subsys B (environment)             *
*                                                                      *
************************************************************************
      Call Get_NameRun(NamRfil) ! save the old RUNFILE name
      Call NameRun('AUXRFIL')   ! switch RUNFILE name
*                                                                      *
************************************************************************
*                                                                      *
      nD=4
      lFck=nh1*nD
      Call Allocate_Work(ipF_DFT,lFck)
      ipFA_DFT=ipF_DFT+2*nh1
      l_D_DS=nh1*nD
      Call GetMem('D-DS','Allo','Real',ip_D_DS,l_D_DS)
      ipA_D_DS=ip_D_DS+2*nh1
      Vxc_ref(1)=Zero
      Vxc_ref(2)=Zero
*
*---- Get the density matrix of the environment (rho_B)
*
      Call Get_iScalar('Multiplicity',kSpin)
      Call Get_D1ao(ipD1ao,nDens)
      If (nDens.ne.nh1) Then
         Call WarningMessage(2,'DrvEMB: nDens.ne.nh1')
         Write (6,*) 'nDens=',nDens
         Write (6,*) 'nh1  =',nh1
         Call Abend()
      End If
      call dcopy_(nh1,Work(ipD1ao),1,Work(ip_D_DS),1)
*     Call RecPrt('D1ao',' ',Work(ipD1ao),nh1,1)
*
      Call GetMem('Dens','Free','Real',ipD1ao,nDens)
*
*---- Get the spin density matrix of the environment
*
      If (kSpin.ne.1) Then
         Call Get_D1Sao(ipD1Sao,nDens)
*        Call RecPrt('D1Sao',' ',Work(ipD1Sao),nh1,1)
         call dcopy_(nh1,Work(ipD1Sao),1,Work(ip_D_DS+nh1),1)
         Call GetMem('Dens','Free','Real',ipD1Sao,nDens)
      End If
*
*---- Compute alpha and beta density matrices of the environment
*
      nFckDim=2
      If (kSpin.eq.1) Then
         call dscal_(nh1,Half,Work(ip_D_DS),1)
         call dcopy_(nh1,Work(ip_D_DS),1,Work(ip_D_DS+nh1),1)
         nFckDim=1
      Else
         Do i = 1, nh1
            DTot=Work(ip_D_DS+i-1)
            DSpn=Work(ip_D_DS+i-1+nh1)
            d_Alpha=Half*(DTot+DSpn)
            d_Beta =Half*(DTot-DSpn)
            Work(ip_D_DS+i-1)=    d_Alpha
            Work(ip_D_DS+i-1+nh1)=d_Beta
         End Do
*      Call RecPrt('Da',' ',Work(ip_D_DS),nh1,1)
*      Call RecPrt('Db',' ',Work(ip_D_DS+nh1),nh1,1)
      End If
*
      If (OFE_first) Then

         Call wrap_DrvNQ(KSDFT,Work(ipF_DFT),nFckDim,Func_B,
     &                   Work(ip_D_DS),nh1,nFckDim,
     &                   Do_Grad,
     &                   Grad,nGrad,DFTFOCK)

         If (KSDFT(1:4).eq.'NDSD') Then
            l_NDSD=nFckDim*nh1
            Call GetMem('NDSD','Allo','Real',ip_NDSD,l_NDSD)
            call dcopy_(l_NDSD,Work(ipF_DFT),1,Work(ip_NDSD),1)
            KSDFT(1:4)='LDTF' !set to Thomas-Fermi for subsequent calls
         EndIf

      EndIf
*                                                                      *
************************************************************************
*                                                                      *
*     Setup of density matrices for subsys A                           *
*                                                                      *
************************************************************************
      Call NameRun(NamRfil)    ! switch back RUNFILE name
*
*---- Get the density matrix for rho_A
*
      Call Get_D1ao(ipD1ao,nDens)
      If (nDens.ne.nh1) Then
         Call WarningMessage(2,'DrvEMB: nDens.ne.nh1')
         Write (6,*) 'nDens=',nDens
         Write (6,*) 'nh1  =',nh1
         Call Abend()
      End If
      call dcopy_(nh1,Work(ipD1ao),1,Work(ipA_D_DS),1)
*     Call RecPrt('D1ao',' ',Work(ipD1ao),nh1,1)
*
      Call GetMem('Dens','Free','Real',ipD1ao,nDens)
*
      Call Get_iScalar('Multiplicity',iSpin)
      If (iSpin.eq.1 .and. kSpin.ne.1 .and. OFE_first) Then
         Call WarningMessage(0,
     &     ' Non-singlet environment perturbation on singlet state!'//
     &     '  Spin-components of the OFE potential will be averaged. ' )
      EndIf
*
*---- Get the spin density matrix of A
*
      If (iSpin.ne.1) Then
         Call Get_D1Sao(ipD1Sao,nDens)
*        Call RecPrt('D1Sao',' ',Work(ipD1Sao),nh1,1)
         call dcopy_(nh1,Work(ipD1Sao),1,Work(ipA_D_DS+nh1),1)
         Call GetMem('Dens','Free','Real',ipD1Sao,nDens)
      End If
*
*---- Compute alpha and beta density matrices of subsystem A
*
      nFckDim=2
      If (iSpin.eq.1) Then
         call dscal_(nh1,Half,Work(ipA_D_DS),1)
         call dcopy_(nh1,Work(ipA_D_DS),1,Work(ipA_D_DS+nh1),1)
         If (kSpin.eq.1) nFckDim=1
      Else
         Do i = 1, nh1
            DTot=Work(ipA_D_DS+i-1)
            DSpn=Work(ipA_D_DS+i-1+nh1)
            d_Alpha=Half*(DTot+DSpn)
            d_Beta =Half*(DTot-DSpn)
            Work(ipA_D_DS+i-1)=    d_Alpha
            Work(ipA_D_DS+i-1+nh1)=d_Beta
         End Do
*      Call RecPrt('Da',' ',Work(ipA_D_DS),nh1,1)
*      Call RecPrt('Db',' ',Work(ipA_D_DS+nh1),nh1,1)
      End If

      Call wrap_DrvNQ(KSDFT,Work(ipFA_DFT),nFckDim,Func_A,
     &                Work(ipA_D_DS),nh1,nFckDim,
     &                Do_Grad,
     &                Grad,nGrad,DFTFOCK)
*
*  Fraction of correlation potential from A (cases: HF or Trunc. CI)
*
      If (dFMD.gt.0.0d0) Then
*
         Call GetMem('Fcorr','Allo','Real',ipFc,nh1*nFckDim)
*
         Call cwrap_DrvNQ(KSDFT,Work(ipFA_DFT),nFckDim,Ec_A,
     &                    Work(ipA_D_DS),nh1,nFckDim,
     &                    Do_Grad,
     &                    Grad,nGrad,DFTFOCK,Work(ipFc))
      End If
*
*
************************************************************************
*                                                                      *
*     Calculation on the supermolecule                                 *
*                                                                      *
************************************************************************
      nFckDim=2
      If (iSpin.eq.1 .and. kSpin.eq.1) Then
         nFckDim=1
         Call daxpy_(nh1,One,Work(ipA_D_DS),1,Work(ip_D_DS),1)
      Else
         Call daxpy_(nh1,One,Work(ipA_D_DS),1,Work(ip_D_DS),1)
         Call daxpy_(nh1,One,Work(ipA_D_DS+nh1),1,Work(ip_D_DS+nh1),1)
      EndIf

      Call wrap_DrvNQ(KSDFT,Work(ipF_DFT),nFckDim,Func_AB,
     &                Work(ip_D_DS),nh1,nFckDim,
     &                Do_Grad,
     &                Grad,nGrad,DFTFOCK)

      Energy_NAD = Func_AB - Func_A - Func_B
*
      If (dFMD.gt.0.0d0) Then
         Call Get_electrons(xElAB)
         Fakt_ = -1.0d0*Xlambda(abs(Energy_NAD)/xElAB,Xsigma)
         Call daxpy_(nh1*nFckDim,Fakt_,Work(ipFc),1,Work(ipFA_DFT),1)
         Call GetMem('Fcorr','Free','Real',ipFc,nh1*nFckDim)
#ifdef _DEBUG_
         write(6,*) ' lambda(E_nad) = ',dFMD*Fakt_
#endif
      EndIf

*                                                                      *
************************************************************************
*                                                                      *
*  Non Additive (NAD) potential: F(AB)-F(A)
      iFick=ipF_DFT
      iFickA=ipFA_DFT
      Do i=1,nFckDim
         Call daxpy_(nh1,-One,Work(iFickA),1,Work(iFick),1)
         iFickA=iFickA+nh1
         iFick=iFick+nh1
      End Do
*
*  NDSD potential for T_nad: add the (B)-dependent term
      iFick=ipF_DFT
      iFickB=ip_NDSD
      Do i=1,nFckDim*Min(1,l_NDSD)
         Call daxpy_(nh1,One,Work(iFickB),1,Work(iFick),1)
         If (kSpin.ne.1) iFickB=iFickB+nh1
         iFick=iFick+nh1
      End Do
*
*     Add the Nuc Attr potential (from subsystem B) and then
*     put out the DFT Fock matrices from the (NAD) embedding potential
*     on the runfile (AUXRFIL). Note that the classical Coulomb
*     interaction potential from subsystem B is computed in the std
*     Fock matrix builders
*
      Call Get_NameRun(NamRfil) ! save the old RUNFILE name
      Call NameRun('AUXRFIL')   ! switch RUNFILE name
*
      Call GetMem('Attr Pot','Allo','Real',ipTmpA,nh1)
      Call Get_dArray('Nuc Potential',Work(ipTmpA),nh1)
*
      Fact = Two ! because Dmat has been scaled by half
      If (kSpin.ne.1) Fact=One
      Fact_=Fact
*
      V_emb=Fact*dDot_(nh1,Work(ipF_DFT),1,Work(ipA_D_DS),1)
      V_Nuc_AB=Fact*dDot_(nh1,Work(ipTmpA),1,Work(ipA_D_DS),1)
      If (kSpin.ne.1) Then
         V_emb=V_emb+Fact*dDot_(nh1,Work(ipF_DFT+nh1),1,
     &                             Work(ipA_D_DS+nh1),1)
         V_Nuc_AB=V_Nuc_AB+Fact*dDot_(nh1,Work(ipTmpA),1,
     &                               Work(ipA_D_DS+nh1),1)
      EndIf
*
*  Averaging the spin-components of F(AB) iff non-spol(A)//spol(B)
      If (iSpin.eq.1 .and. kSpin.ne.1) Then
         Do i=0,nh1-1
            k=ipF_DFT+i
            l=k+nh1
            tmp=Half*(Work(k)+Work(l))
            Work(k)=tmp
         End Do
         nFckDim=1  ! reset stuff as if A+B had been spin compensated
         Fact=Two
      EndIf
*
      iFick=ipF_DFT
      iADmt=ipA_D_DS
      Do i=1,nFckDim
         Call daxpy_(nh1,1.0d0,Work(ipTmpA),1,Work(iFick),1)
         Vxc_ref(i)=Fact*dDot_(nh1,Work(iFick),1,Work(iADmt),1)
         iFick=iFick+nh1
         iADmt=iADmt+nh1
      End Do
*
      If(dFMD.gt.0.0d0) Call Put_dScalar('KSDFT energy',Ec_A)
      Call Put_dArray('Vxc_ref ',Vxc_ref,2)
*
      Call Put_dArray('dExcdRa',Work(ipF_DFT),nh1*nFckDim)
      Call NameRun(NamRfil)   ! switch back RUNFILE name

      Call Get_dArray('Nuc Potential',Work(ipTmpA),nh1)
      V_Nuc_BA= Fact_*( dDot_(nh1,Work(ipTmpA),1,Work(ip_D_DS),1)
     &                 -dDot_(nh1,Work(ipTmpA),1,Work(ipA_D_DS),1))
      If (kSpin.ne.1) Then
         V_Nuc_BA=V_Nuc_BA+Fact_*( dDot_(nh1,Work(ipTmpA),1,
     &                                      Work(ip_D_DS+nh1),1)
     &                            -dDot_(nh1,Work(ipTmpA),1,
     &                                      Work(ipA_D_DS+nh1),1) )
      EndIf
*
      Call GetMem('Attr Pot','Free','Real',ipTmpA,nh1)
*
#ifdef _DEBUG_
      If (nFckDim.eq.1) Then
         Do i=1,nh1
            Write(6,'(i4,f22.16)') i,Work(ipF_DFT+i-1)
         End Do
      Else
         Do i=1,nh1
           Write(6,'(i4,3f22.16)') i,Work(ipF_DFT+i-1),
     &                               Work(ipF_DFT+i-1+nh1),
     &     (Work(ipF_DFT+i-1)+Work(ipF_DFT+i-1+nh1))/2.0d0
         End Do
      End If
      Write(6,'(a,f22.16)') ' NAD DFT Energy :',Energy_NAD
#endif
*
      Call Free_Work(ipF_DFT)
      Call GetMem('D-DS','Free','Real',ip_D_DS,l_D_DS)
      Call Free_iSD()
      Call QExit('DrvEMB')
      Return
c Avoid unused argument warnings
      If (.False.) Then
         Call Unused_real_array(H1)
         Call Unused_real_array(D)
         Call Unused_real(RepNuc)
         Call Unused_real(ExFac)
         Call Unused_real_array(D1I)
         Call Unused_real_array(D1A)
      End If
      End
************************************************************************
*                                                                      *
************************************************************************
*                                                                      *
************************************************************************
      Subroutine Wrap_DrvNQ(KSDFT,F_DFT,nFckDim,Func,
     &                      D_DS,nh1,nD_DS,
     &                      Do_Grad,
     &                      Grad,nGrad,DFTFOCK)
      Implicit Real*8 (a-h,o-z)
      Character*(*) KSDFT
      Integer nh1, nFckDim, nD_DS
      Real*8 F_DFT(nh1,nFckDim), D_DS(nh1,nD_DS), Func
      Logical Do_Grad
      Real*8 Grad(nGrad)
      Character*4 DFTFOCK
#include "real.fh"
#include "WrkSpc.fh"
#include "nq_info.fh"
#include "debug.fh"
      External LSDA_emb,
     &         LSDA5_emb,
     &         BLYP_emb, BLYP_emb2,
     &         PBE_emb, PBE_emb2,
     &         vW_hunter, nucatt_emb,
     &         Checker
      Logical  Do_MO,Do_TwoEl,F_nAsh

************************************************************************
*                                                                      *
*     DFT functionals, compute integrals over the potential
*
      Func            =Zero
      Dens_I          =Zero
      Grad_I          =Zero
      Tau_I           =Zero
      Do_MO           =.False.
      Do_TwoEl        =.False.
*
      Call Get_iScalar('nSym',mIrrep)
      Call Get_iArray('nBas',mBas(0),mIrrep)
      Call Get_iArray('nFro',nFro(0),mIrrep)
      Call Get_iArray('nIsh',nIsh(0),mIrrep)
      Call qpg_dArray('nAsh',F_nAsh,nOrbA)
      If(.not.F_nAsh .or. nOrbA.eq.0) Then
         Call Izero(nAsh(0),mIrrep)
      Else
         Call Get_iArray('nAsh',nAsh(0),mIrrep)
      End If
*                                                                      *
************************************************************************
*                                                                      *
*      LDTF/LSDA (Thomas-Fermi for KE)                                 *
*                                                                      *
       If (KSDFT.eq.'LDTF/LSDA ' .or.
     &     KSDFT.eq.'LDTF/LDA  ') Then
         ExFac=Get_ExFac(KSDFT(6:10)//' ')
         Functional_type=LDA_type
         Call DrvNQ(LSDA_emb,F_DFT,nFckDim,Func,
     &              D_DS,nh1,nD_DS,
     &              Do_Grad,
     &              Grad,nGrad,
     &              Do_MO,Do_TwoEl,DFTFOCK)
*                                                                      *
************************************************************************
*                                                                      *
*      LDTF/LSDA5 (Thomas-Fermi for KE)                                *
*                                                                      *
       Else If (KSDFT.eq.'LDTF/LSDA5' .or.
     &          KSDFT.eq.'LDTF/LDA5 ') Then
         ExFac=Get_ExFac(KSDFT(6:10)//' ')
         Functional_type=LDA_type
         Call DrvNQ(LSDA5_emb,F_DFT,nFckDim,Func,
     &              D_DS,nh1,nD_DS,
     &              Do_Grad,
     &              Grad,nGrad,
     &              Do_MO,Do_TwoEl,DFTFOCK)
*                                                                      *
************************************************************************
*                                                                      *
*      LDTF/PBE   (Thomas-Fermi for KE)                                *
*                                                                      *
       Else If (KSDFT.eq.'LDTF/PBE  ') Then
         ExFac=Get_ExFac(KSDFT(6:10)//' ')
         Functional_type=GGA_type
         Call DrvNQ(PBE_emb,F_DFT,nFckDim,Func,
     &              D_DS,nh1,nD_DS,
     &              Do_Grad,
     &              Grad,nGrad,
     &              Do_MO,Do_TwoEl,DFTFOCK)
*                                                                      *
************************************************************************
*                                                                      *
*      NDSD/PBE   (NDSD for KE)                                        *
*                                                                      *
       Else If (KSDFT.eq.'NDSD/PBE  ') Then
         ExFac=Get_ExFac(KSDFT(6:10)//' ')
         Functional_type=meta_GGA_type2
         Call DrvNQ(PBE_emb2,F_DFT,nFckDim,Func,
     &              D_DS,nh1,nD_DS,
     &              Do_Grad,
     &              Grad,nGrad,
     &              Do_MO,Do_TwoEl,DFTFOCK)
*                                                                      *
************************************************************************
*                                                                      *
*      LDTF/BLYP  (Thomas-Fermi for KE)                                *
*                                                                      *
       Else If (KSDFT.eq.'LDTF/BLYP ') Then
         ExFac=Get_ExFac(KSDFT(6:10)//' ')
         Functional_type=GGA_type
         Call DrvNQ(BLYP_emb,F_DFT,nFckDim,Func,
     &              D_DS,nh1,nD_DS,
     &              Do_Grad,
     &              Grad,nGrad,
     &              Do_MO,Do_TwoEl,DFTFOCK)
*                                                                      *
************************************************************************
*                                                                      *
*      NDSD/BLYP  (NDSD for KE)                                        *
*                                                                      *
       Else If (KSDFT.eq.'NDSD/BLYP ') Then
         ExFac=Get_ExFac(KSDFT(6:10)//' ')
         Functional_type=meta_GGA_type2
         Call DrvNQ(BLYP_emb2,F_DFT,nFckDim,Func,
     &              D_DS,nh1,nD_DS,
     &              Do_Grad,
     &              Grad,nGrad,
     &              Do_MO,Do_TwoEl,DFTFOCK)
*                                                                      *
************************************************************************
*                                                                      *
*      HUNTER  (von Weizsacker KE, no calc of potential)               *
*                                                                      *
       Else If (KSDFT.eq.'HUNTER') Then
         ExFac=Zero
         Functional_type=GGA_type
         Call DrvNQ(vW_hunter,F_DFT,nFckDim,Func,
     &              D_DS,nh1,nD_DS,
     &              Do_Grad,
     &              Grad,nGrad,
     &              Do_MO,Do_TwoEl,DFTFOCK)
*                                                                      *
************************************************************************
*                                                                      *
*      NUCATT                                                          *
*                                                                      *
       Else If (KSDFT.eq.'NUCATT_EMB') Then
         ExFac=Zero
         Functional_type=LDA_type
         Call DrvNQ(nucatt_emb,F_DFT,nFckDim,Func,
     &              D_DS,nh1,nD_DS,
     &              Do_Grad,
     &              Grad,nGrad,
     &              Do_MO,Do_TwoEl,DFTFOCK)
*                                                                      *
************************************************************************
*                                                                      *
*     Checker
      Else If (KSDFT.eq.'CHECKER') Then
         ExFac=Zero
         Functional_type=meta_GGA_type2
         Call DrvNQ(Checker,F_DFT,nFckDim,Func,
     &              D_DS,nh1,nD_DS,
     &              Do_Grad,
     &              Grad,nGrad,
     &              Do_MO,Do_TwoEl,DFTFOCK)
*                                                                      *
************************************************************************
*                                                                      *
      Else
         lKSDFT=LEN(KSDFT)
         Call WarningMessage(2,
     &               ' Wrap_DrvNQ: Undefined functional type!')
         Write (6,*) '         Functional=',KSDFT(1:lKSDFT)
         Call Quit_OnUserError()
      End If
*
      Return
      End
************************************************************************
*                                                                      *
************************************************************************
      Subroutine cWrap_DrvNQ(KSDFT,F_DFT,nFckDim,Func,
     &                       D_DS,nh1,nD_DS,
     &                       Do_Grad,
     &                       Grad,nGrad,DFTFOCK,F_corr)
      Implicit Real*8 (a-h,o-z)
      Character*(*) KSDFT
      Integer nh1, nFckDim, nD_DS
      Real*8 F_DFT(nh1,nFckDim), D_DS(nh1,nD_DS), Func
      Real*8 F_corr(nh1,nFckDim)
      Logical Do_Grad
      Real*8 Grad(nGrad)
      Character*4 DFTFOCK
#include "real.fh"
#include "WrkSpc.fh"
#include "nq_info.fh"
#include "debug.fh"
      External VWN_III_emb,
     &         VWN_V_emb,
     &         cBLYP_emb,
     &         cPBE_emb,
     &         Checker
      Logical  Do_MO,Do_TwoEl,F_nAsh

************************************************************************
*                                                                      *
      Func            =Zero
      Dens_I          =Zero
      Grad_I          =Zero
      Tau_I           =Zero
      Do_MO           =.False.
      Do_TwoEl        =.False.
*
      Call Get_iScalar('nSym',mIrrep)
      Call Get_iArray('nBas',mBas(0),mIrrep)
      Call Get_iArray('nFro',nFro(0),mIrrep)
      Call Get_iArray('nIsh',nIsh(0),mIrrep)
      Call qpg_dArray('nAsh',F_nAsh,nOrbA)
      If(.not.F_nAsh .or. nOrbA.eq.0) Then
         Call Izero(nAsh(0),mIrrep)
      Else
         Call Get_iArray('nAsh',nAsh(0),mIrrep)
      End If
*                                                                      *
************************************************************************
*                                                                      *
*      LDTF/LSDA (Fractional) correlation potential only               *
*                                                                      *
       If (KSDFT.eq.'LDTF/LSDA ' .or.
     &     KSDFT.eq.'LDTF/LDA  ') Then
         ExFac=Get_ExFac(KSDFT(6:10)//' ')
         Functional_type=LDA_type
         Call DrvNQ(VWN_III_emb,F_corr,nFckDim,Func,
     &              D_DS,nh1,nD_DS,
     &              Do_Grad,
     &              Grad,nGrad,
     &              Do_MO,Do_TwoEl,DFTFOCK)
*                                                                      *
************************************************************************
*                                                                      *
*      LDTF/LSDA5 (Fractional) correlation potential only              *
*                                                                      *
       Else If (KSDFT.eq.'LDTF/LSDA5' .or.
     &          KSDFT.eq.'LDTF/LDA5 ') Then
         ExFac=Get_ExFac(KSDFT(6:10)//' ')
         Functional_type=LDA_type
         Call DrvNQ(VWN_V_emb,F_corr,nFckDim,Func,
     &              D_DS,nh1,nD_DS,
     &              Do_Grad,
     &              Grad,nGrad,
     &              Do_MO,Do_TwoEl,DFTFOCK)
*                                                                      *
************************************************************************
*                                                                      *
*      LDTF/PBE   (Fractional) correlation potential only              *
*                                                                      *
       Else If (KSDFT.eq.'LDTF/PBE  ' .or.
     &          KSDFT.eq.'NDSD/PBE  ') Then
         ExFac=Get_ExFac(KSDFT(6:10)//' ')
         Functional_type=GGA_type
         Call DrvNQ(cPBE_emb,F_corr,nFckDim,Func,
     &              D_DS,nh1,nD_DS,
     &              Do_Grad,
     &              Grad,nGrad,
     &              Do_MO,Do_TwoEl,DFTFOCK)
*                                                                      *
************************************************************************
*                                                                      *
*      LDTF/BLYP  (Fractional) correlation potential only              *
*                                                                      *
       Else If (KSDFT.eq.'LDTF/BLYP ' .or.
     &          KSDFT.eq.'NDSD/BLYP ') Then
         ExFac=Get_ExFac(KSDFT(6:10)//' ')
         Functional_type=GGA_type
         Call DrvNQ(cBLYP_emb,F_corr,nFckDim,Func,
     &              D_DS,nh1,nD_DS,
     &              Do_Grad,
     &              Grad,nGrad,
     &              Do_MO,Do_TwoEl,DFTFOCK)
*                                                                      *
************************************************************************
*                                                                      *
*     Checker                                                          *
*                                                                      *
      Else If (KSDFT.eq.'CHECKER') Then
         ExFac=Zero
         Functional_type=meta_GGA_type2
         Call DrvNQ(Checker,F_corr,nFckDim,Func,
     &              D_DS,nh1,nD_DS,
     &              Do_Grad,
     &              Grad,nGrad,
     &              Do_MO,Do_TwoEl,DFTFOCK)
*                                                                      *
************************************************************************
*                                                                      *
      Else
         lKSDFT=LEN(KSDFT)
         Call WarningMessage(2,
     &               ' cWrap_DrvNQ: Undefined functional type!')
         Write (6,*) '         Functional=',KSDFT(1:lKSDFT)
         Call Quit_OnUserError()
      End If
*
      Return
c Avoid unused argument warnings
      If (.False.) Call Unused_real_array(F_DFT)
      End
************************************************************************
*                                                                      *
************************************************************************
*                                                                      *
************************************************************************
      Real*8 Function Xlambda(omega,sigma)
      Implicit Real*8 (a-h,o-z)
      Real*8 omega, sigma

      If (sigma*omega.gt.42d0) Then
         Xlambda = 1.0d0
      Else
         Xlambda = 1.0d0 - exp(-sigma*omega)
      EndIf

      End
************************************************************************
*                                                                      *
************************************************************************
      Subroutine Get_electrons(xnElect)
      Implicit Real*8 (a-h,o-z)
      Real*8 xnElect
#include "real.fh"
#include "nq_info.fh"

      xnElect = Dens_I

      Return
      End
