! energy_anchor
!> @brief Calculate energy of anchor option

! ************************************************************************
subroutine energy_anchor(irep, energy_unit, energy)

  use const_maxsize
  use const_index
  use var_setp, only : inmisc
  use var_struct, only : xyz_mp_rep, imp2unit, grp
  implicit none

  ! ------------------------------------------------------------
  integer,    intent(in)    :: irep
  real(PREC), intent(inout) :: energy_unit(:,:,:) ! (unit, unit, E_TYPE%MAX)
  real(PREC), intent(inout) :: energy(:)         ! (E_TYPE%MAX)

  ! ----------------------------------------------------------------------
  ! local variables
  integer :: ianc, imp, iunit, junit, igrp, ilist
  real(PREC) :: dist, cbd2, efull
  real(PREC) :: ixyz(3)
  ! ----------------------------------------------------------------------
  do ianc = 1, inmisc%nanc
   
     imp = inmisc%ianc2mp(ianc)

     dist = norm2(xyz_mp_rep(:, imp, irep) - inmisc%anc_xyz(:, ianc))

     if(dist > inmisc%anc_dist(ianc)) then
        cbd2 = inmisc%coef_anc(ianc)
        efull = cbd2 * (dist - inmisc%anc_dist(ianc))**2
   
        energy(E_TYPE%ANCHOR) = energy(E_TYPE%ANCHOR) + efull
        iunit = imp2unit(imp)
        junit = iunit
        energy_unit(iunit, junit, E_TYPE%ANCHOR) =  &
                   energy_unit(iunit, junit, E_TYPE%ANCHOR) + efull
     end if

  enddo

  do ianc = 1, inmisc%nanc_com_ini

     igrp = inmisc%ianc_com_ini2grp(ianc)
     
     ixyz(:) = 0.0
     do ilist = 1, grp%nmp(igrp)
        ixyz(:) = &
             ixyz(:) + &
             xyz_mp_rep(:, grp%implist(ilist, igrp), irep) * &
             grp%mass_fract(ilist, igrp)
     end do

     dist = norm2(ixyz(:) - inmisc%anc_com_ini_xyz(:, ianc, irep))

     if(dist > inmisc%anc_com_ini_dist(ianc)) then
        cbd2 = inmisc%coef_anc_com_ini(ianc)
        efull = cbd2 * (dist - inmisc%anc_com_ini_dist(ianc))**2
        energy(E_TYPE%ANCHOR) = energy(E_TYPE%ANCHOR) + efull
     end if

  end do
  
end subroutine energy_anchor
