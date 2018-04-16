!***********************************************************************
! This file is part of OpenMolcas.                                     *
!                                                                      *
! OpenMolcas is free software; you can redistribute it and/or modify   *
! it under the terms of the GNU Lesser General Public License, v. 2.1. *
! OpenMolcas is distributed in the hope that it will be useful, but it *
! is provided "as is" and without any express or implied warranties.   *
! For more details see the full text of the license in the file        *
! LICENSE or in <http://www.gnu.org/licenses/>.                        *
!***********************************************************************
  subroutine dens2file(array1,array2,array3,adim,lu,adr)
  implicit none

  integer, intent(in) :: adim, lu, adr
  real*8 , intent(in) :: array1(*),array2(*),array3(*)
  integer :: idisk

    idisk = adr
    ! note that ddafile modifies idisk
    call ddafile(lu,1,array1,adim,idisk)
    call ddafile(lu,1,array2,adim,idisk)
    call ddafile(lu,1,array3,adim,idisk)

  end subroutine dens2file
