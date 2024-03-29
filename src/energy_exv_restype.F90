!energy_exv_restype
!>@brief Calculates the excluded volume interactions with
!>   residue-type-dependent radii.
!> The values are added into "energy(ENERGY%EXV)" and "energy_unit(ENERGY%EXV)".

subroutine  energy_exv_restype(irep, energy_unit, energy)

  use const_maxsize
  use const_physical
  use const_index
  use var_setp,  only : inexv, inperi
  use var_struct,only : imp2unit, xyz_mp_rep, pxyz_mp_rep, lexv, iexv2mp, exv_radius_mp
  use mpiconst

  implicit none

  integer,    intent(in)  :: irep
  real(PREC), intent(out) :: energy(:)         ! (E_TYPE%MAX)
  real(PREC), intent(out) :: energy_unit(:,:,:) ! (MXUNIT, MXUNIT, E_TYPE%MAX)

  integer :: ksta, kend
  integer :: imp1, imp2, iunit, junit
  integer :: iexv, imirror
  real(PREC) :: dist2
  real(PREC) :: coef
  real(PREC) :: cdist2
  real(PREC) :: cutoff2, cutoff02, revcutoff12

  real(PREC) :: roverdist2, roverdist4
  real(PREC) :: roverdist8, roverdist12
  real(PREC) :: ene 
  real(PREC) :: v21(SDIM)
#ifdef MPI_PAR3
  integer :: klen
#endif

  ! ------------------------------------------------------------------------
  ! The formula of (r/x)**12 repulsion energy
  !
  ! energy = coef * [ (sigma/dist)**12 - (1/cutoff)**12]
  ! sigma = exv_radius_mp(i) + exv_radius_mp(j)
  !
  ! ------------------------------------------------------------------------

  ! for speed up
  coef = inexv%exv_coef
  cutoff02 = inexv%exv12_cutoff * inexv%exv12_cutoff
  revcutoff12 = 1 / cutoff02**6

#ifdef MPI_PAR3
#ifdef SHARE_NEIGH_PNL
  klen=(lexv(2,E_TYPE%EXV12,irep)-lexv(1,E_TYPE%EXV12,irep)+npar_mpi)/npar_mpi
  ksta=lexv(1,E_TYPE%EXV12,irep)+klen*local_rank_mpi
  kend=min(ksta+klen-1,lexv(2,E_TYPE%EXV12,irep))
#else
  ksta = lexv(1, E_TYPE%EXV12, irep)
  kend = lexv(2, E_TYPE%EXV12, irep)
#endif
#else
  ksta = lexv(1, E_TYPE%EXV12, irep)
  kend = lexv(2, E_TYPE%EXV12, irep)
#endif
  !$omp do private(imp1,imp2,v21,dist2,cutoff2,cdist2, &
  !$omp&           roverdist2,roverdist4, &
  !$omp&           roverdist8,roverdist12,ene,iunit,junit,imirror)
  do iexv=ksta, kend

     imp1 = iexv2mp(1, iexv, irep)
     imp2 = iexv2mp(2, iexv, irep)

     if(inperi%i_periodic == 0) then
        v21(1:3) = xyz_mp_rep(1:3, imp2, irep) - xyz_mp_rep(1:3, imp1, irep)
     else
        imirror = iexv2mp(3, iexv, irep)
        v21(1:3) = pxyz_mp_rep(1:3, imp2, irep) - pxyz_mp_rep(1:3, imp1, irep) + inperi%d_mirror(1:3, imirror)
     end if

     dist2 = v21(1)*v21(1) + v21(2)*v21(2) + v21(3)*v21(3)

     ! --------------------------------------------------------------------
     cdist2 = ( exv_radius_mp(imp1) + exv_radius_mp(imp2) )**2
     cutoff2 = cutoff02 * cdist2

     if(dist2 > cutoff2) cycle

     ! --------------------------------------------------------------------
     roverdist2 = cdist2 / dist2
     roverdist4 = roverdist2 * roverdist2
     roverdist8 = roverdist4 * roverdist4
     roverdist12 = roverdist4 * roverdist8
     ene = coef * (roverdist12 - revcutoff12)

     ! --------------------------------------------------------------------
     ! sum of the energy
     energy(E_TYPE%EXV12) = energy(E_TYPE%EXV12) + ene

     iunit = imp2unit(imp1)
     junit = imp2unit(imp2)
     energy_unit(iunit, junit, E_TYPE%EXV12) = energy_unit(iunit, junit, E_TYPE%EXV12) + ene
  end do
  !$omp end do nowait

end subroutine energy_exv_restype
