!force_exv_wca
!> @brief Calculates the force related to excluded volume

subroutine force_exv_wca(irep, force_mp)

  use const_maxsize
  use const_physical
  use const_index
  use var_setp,   only : indtrna13, inperi
  use var_struct, only : nmp_all, pxyz_mp_rep, lexv, iexv2mp
  use var_simu,   only : istep
  use mpiconst

  implicit none

  integer,    intent(in)    :: irep
  real(PREC), intent(inout) :: force_mp(SDIM, nmp_all)

  integer :: ksta, kend
  integer :: imp1, imp2,iexv, imirror
  real(PREC) :: dist2, coef, cdist2
  real(PREC) :: roverdist2, roverdist4, roverdist8, roverdist14
  real(PREC) :: dvdw_dr
  real(PREC) :: v21(SDIM), for(SDIM)
#ifdef SHARE_NEIGH_PNL
  integer :: klen
#endif
  character(CARRAY_MSG_ERROR) :: error_message

  ! --------------------------------------------------------------------
  !! Currently this potential is available noly for RNA.
  cdist2 = indtrna13%exv_dist**2
  coef = 12.0e0_PREC * indtrna13%exv_coef / cdist2
  !cdist2_pro = inpro%cdist_exvwca**2
  !coef_pro = 12.0e0_PREC * inpro%cexvwca / cdist2_pro
  !if (inmisc%class_flag(CLASS%RNA)) then
  !   cdist2_rna = inrna%cdist_exvwca**2
  !   coef_rna = 12.0e0_PREC * inrna%cexvwca / cdist2_rna
  !   cdist2_rna_pro = (inrna%cdist_exvwca + inpro%cdist_exvwca) ** 2 / 4
  !   coef_rna_pro = 12.0e0_PREC * inrna%cexvwca / cdist2_rna_pro
  !endif
  !if (inmisc%class_flag(CLASS%LIG)) then
  !   cdist2_llig = inligand%cdist_exvwca_llig**2
  !   coef_llig = 12.0e0_PREC * inligand%cexvwca / cdist2_llig
  !   cdist2_lpro = inligand%cdist_exvwca_lpro**2
  !   coef_lpro = 12.0e0_PREC * inligand%cexvwca / cdist2_lpro
  !endif

#ifdef MPI_PAR
#ifdef SHARE_NEIGH_PNL
  klen=(lexv(2,E_TYPE%EXV_WCA,irep)-lexv(1,E_TYPE%EXV_WCA,irep)+npar_mpi)/npar_mpi
  ksta=lexv(1,E_TYPE%EXV_WCA,irep)+klen*local_rank_mpi
  kend=min(ksta+klen-1,lexv(2,E_TYPE%EXV_WCA,irep))
#else
  ksta = lexv(1, E_TYPE%EXV_WCA, irep)
  kend = lexv(2, E_TYPE%EXV_WCA, irep)
#endif
#ifdef MPI_DEBUG
  print *,"exv_wca      = ", kend-ksta+1
#endif
#else
  ksta = lexv(1, E_TYPE%EXV_WCA, irep)
  kend = lexv(2, E_TYPE%EXV_WCA, irep)
#endif
!$omp do private(imp1,imp2,v21,dist2,&
!$omp&           roverdist2,roverdist4, &
!$omp&           roverdist8,roverdist14,dvdw_dr,for,imirror)
  do iexv=ksta, kend

     imp1 = iexv2mp(1, iexv, irep)
     imp2 = iexv2mp(2, iexv, irep)
     imirror = iexv2mp(3, iexv, irep)

     !if(inperi%i_periodic == 0) then
     !   v21(1:3) = xyz_mp_rep(1:3, imp2, irep) - xyz_mp_rep(1:3, imp1, irep)
     !else
        v21(1:3) = pxyz_mp_rep(1:3, imp2, irep) - pxyz_mp_rep(1:3, imp1, irep) + inperi%d_mirror(1:3, imirror)
     !end if

     dist2 = dot_product(v21,v21)

     !! Currently this potential is available noly for RNA.
     !if (iclass_mp(imp1) == CLASS%RNA .AND. iclass_mp(imp2) == CLASS%RNA) then
     !   cdist2  = cdist2_rna
     !   coef    = coef_rna
     !else if ((iclass_mp(imp1) == CLASS%RNA .AND. iclass_mp(imp2) == CLASS%PRO) .OR. &
     !         (iclass_mp(imp1) == CLASS%PRO .AND. iclass_mp(imp2) == CLASS%RNA)) then
     !   cdist2  = cdist2_rna_pro
     !   coef    = coef_rna_pro
     !else if(iclass_mp(imp1) == CLASS%LIG .OR. iclass_mp(imp2)==CLASS%LIG)then
     !   cdist2  = cdist2_llig
     !   coef    = coef_llig
     !   if(iclass_mp(imp1) == CLASS%PRO .OR. iclass_mp(imp2)==CLASS%PRO)then
     !      cdist2  = cdist2_lpro
     !      coef    = coef_lpro
     !   end if
     !else
     !   cdist2  = cdist2_pro
     !   coef    = coef_pro
     !endif

     if(dist2 > cdist2) cycle
     
     ! -----------------------------------------------------------------
     roverdist2 = cdist2 / dist2
     roverdist4 = roverdist2 * roverdist2
     roverdist8 = roverdist4 * roverdist4
     roverdist14 = roverdist2 * roverdist4 * roverdist8
     dvdw_dr = coef * (roverdist14 - roverdist8)
     if(dvdw_dr > DE_MAX) then
        write(error_message,*) 'exv_wca > DE_MAX', istep, imp1, imp2, sqrt(dist2), dvdw_dr
        call util_error(ERROR%WARN_ALL, error_message)
        dvdw_dr = DE_MAX
     end if

     for(1:3) = dvdw_dr * v21(1:3)
     force_mp(1:3, imp2) = force_mp(1:3, imp2) + for(1:3)
     force_mp(1:3, imp1) = force_mp(1:3, imp1) - for(1:3)
  end do
!$omp end do nowait

end subroutine force_exv_wca
