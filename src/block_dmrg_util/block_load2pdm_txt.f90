!***********************************************************************
! This file is part of OpenMolcas.                                     *
!                                                                      *
! OpenMolcas is free software; you can redistribute it and/or modify   *
! it under the terms of the GNU Lesser General Public License, v. 2.1. *
! OpenMolcas is distributed in the hope that it will be useful, but it *
! is provided "as is" and without any express or implied warranties.   *
! For more details see the full text of the license in the file        *
! LICENSE or in <http://www.gnu.org/licenses/>.                        *
!                                                                      *
! Copyright (C) 2018, Quan Phung                                       *
!***********************************************************************
! Load text file 2RDM generated by BLOCK

subroutine block_load2pdm_txt( NAC, PT, CHEMROOT, TRANS )

  IMPLICIT NONE
  INTEGER, INTENT(IN) :: NAC, CHEMROOT
  REAL*8, INTENT(OUT) :: PT( NAC, NAC, NAC, NAC )
  LOGICAL, INTENT(IN) :: TRANS
  REAL*8 :: PTtemp
  INTEGER :: nac4

  CHARACTER(LEN=50) :: file_2rdm

  INTEGER :: i, idx1, idx2, idx3, idx4, irdm, lu
  INTEGER :: nact, isFreeUnit
  character(len=10) :: rootindex

  external isFreeUnit

  nac4 = nac**4
  call dcopy_(nac4,0.0d0,0,PT,1)
!  PT = 0.0d0

  write(rootindex,"(I2)") chemroot-1
  if (trans) then
    file_2rdm="./node0/spatial_twopdm."//trim(adjustl(rootindex))//"."//trim(adjustl(rootindex))//".txt.trans"
  else
    file_2rdm="./node0/spatial_twopdm."//trim(adjustl(rootindex))//"."//trim(adjustl(rootindex))//".txt"
  endif
  file_2rdm=trim(adjustl(file_2rdm))

  call f_inquire(file_2rdm, irdm)
  if (.NOT. irdm) then
     write(6,'(1X,A15,I3,A16)') 'BLOCK> Root: ',CHEMROOT,' :: No 2RDM file'
     call abend()
  endif

  LU=isFreeUnit(40)
  call molcas_open(LU,file_2rdm)

  read(LU,*) nact

! sort <i,j,k,l> (in row-major) to G(i,l,j,k) (in col-major)
! i.e. G(i,j,k,l) = <i,k,l,j>
! Scale by 2.0 since Block calculates 1/2

  do i=1,nac4
    read(LU,*) idx1, idx2, idx3, idx4, PTtemp
    PT( idx1+1, idx4+1, idx2+1, idx3+1 ) = 2.0d0*PTtemp
  enddo

  close(LU)

end subroutine
