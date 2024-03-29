! neighbor_assign
!> @brief Assignment and sorting of neighborling list for each energy type

#ifdef TIME
#define TIME_S(x) call time_s(x)
#define TIME_E(x) call time_e(x)
#else
#define TIME_S(x) !
#define TIME_E(x) !
#endif

! *********************************************************************
subroutine neighbor_assign(irep, ineigh2mp, lmp2neigh)
  
  use if_neighbor
  use if_util
  use const_maxsize
  use const_index
  use const_physical
  use var_replica,only : irep2grep
  use var_setp,   only : inexv, inpro, inmisc, indtrna13, indtrna, inperi, insopsc !, inrna
  use var_struct, only : nunit_real, pxyz_mp_rep, &
                         imp2unit, lmp2con, icon2mp, coef_go, iexv2mp, exv2para, imp2type, &
                         lmp2LJ, iLJ2mp, coef_LJ, &
                         lmp2wca,iwca2mp,coef_wca, &
                         iclass_unit, ires_mp, nmp_all, &
                         lmp2charge, coef_charge, &
                         exv_radius_mp, exv_epsilon_mp
!                         lmp2morse, &!lmp2rna_bp, lmp2rna_st, &
!                         imorse2mp, &!irna_bp2mp, irna_st2mp, &
!                         coef_morse_a, coef_morse_fD
!                         coef_rna_bp, coef_rna_bp_a, coef_rna_bp_fD, &
!                         coef_rna_st, coef_rna_st_a, coef_rna_st_fD, & 
!                        cmp2atom   !sasa
  use time
  use mpiconst

  implicit none

  ! -------------------------------------------------------------------
  integer, intent(in) :: irep
  integer, intent(in) :: lmp2neigh((nmp_l+nthreads-1)/nthreads  ,0:nthreads-1)
  integer, intent(in) :: ineigh2mp(MXMPNEIGHBOR*nmp_all/nthreads,0:nthreads-1)

  ! -------------------------------------------------------------------
  ! local variables
  integer :: n, grep, d_res
  integer :: klen, ksta, kend
  integer :: inum, imp, jmp, kmp
  integer :: imirror
  integer :: iunit, junit
  integer :: isep_nlocal
  integer :: isep_nlocal_rna
  integer :: icon, iLJ, iwca, iexv, nexv
  integer :: istart, isearch_con, isearch_LJ, isearch_wca
!  integer :: isearch_rna_bp, isearch_rna_st, isearch_morse
  integer :: i_exvol
!  integer :: i_sasa
  integer :: i_exv_wca, i_exv_dt15, i_exv_gauss
  integer :: iexv2mp_l  (3, MXMPNEIGHBOR*nmp_all)
  integer :: iexv2mp_pre(3, MXMPNEIGHBOR*nmp_all)
  integer :: nexv_lall(0:npar_mpi-1)
  !integer :: ii, iz
  real(PREC) :: vx(3)
  real(PREC) :: sigma

  type calc_type
     integer :: GO
     integer :: LJ
     integer :: WCA
!     integer :: MORSE
     integer :: EXV12
     integer :: EXV6
!     integer :: PAIR_RNA
!     integer :: STACK_RNA
!     integer :: AICG1
!     integer :: AICG2
!     integer :: SASA   !sasa
     integer :: EXV_WCA
     integer :: EXV_GAUSS
     integer :: EXV_DT15
     integer :: MAX
  endtype calc_type
  !type(calc_type), parameter :: CALC = calc_type(1,2,3,4,5,6,7,8,9,10,11,12,12)
  type(calc_type), parameter :: CALC = calc_type(1,2,3,4,5,6,7,8,8)
  integer :: icalc(CALC%MAX, nunit_real, nunit_real)

  character(CARRAY_MSG_ERROR) :: error_message

  integer :: imp_l
#ifdef SHARE_NEIGH_PNL
  integer :: iexv2mp_l_sort(3, MXMPNEIGHBOR*nmp_all)
  integer :: disp(0:npar_mpi-1)
  integer :: count(0:npar_mpi-1)
  integer :: nexv_l
#endif

#ifdef _DEBUG
  write(6,*) '####### start neighbor_assign'
#endif

  ! -------------------------------------------------------------------
  isep_nlocal  = inpro%n_sep_nlocal

  grep = irep2grep(irep)

  iexv     = 0
  isearch_con = 1
  isearch_LJ  = 1
  isearch_wca = 1
!  isearch_morse  = 1
!  isearch_rna_bp = 1
!  isearch_rna_st = 1

  ! --------------------------------------------------------------------
  ! calc icalc
  icalc(1:CALC%MAX, 1:nunit_real, 1:nunit_real) = 0

  do iunit = 1, nunit_real
     do junit = iunit, nunit_real
        if(inmisc%flag_nlocal_unit(iunit, junit, INTERACT%GO)) then
           icalc(CALC%GO, iunit, junit) = 1
        end if
        if(inmisc%flag_nlocal_unit(iunit, junit, INTERACT%LJ)) then
           icalc(CALC%LJ, iunit, junit) = 1
        end if
        if(inmisc%flag_nlocal_unit(iunit, junit, INTERACT%WCA)) then
           icalc(CALC%WCA, iunit, junit) = 1
        end if
!        if(inmisc%flag_nlocal_unit(iunit, junit, INTERACT%MORSE)) then
!           icalc(CALC%MORSE, iunit, junit) = 1
!        end if
        if(inmisc%flag_nlocal_unit(iunit, junit, INTERACT%EXV12)) then
           icalc(CALC%EXV12, iunit, junit) = 1
        end if
        if(inmisc%flag_nlocal_unit(iunit, junit, INTERACT%EXV6)) then
           icalc(CALC%EXV6, iunit, junit) = 1
        end if
!        if (inmisc%flag_nlocal_unit(iunit, junit, INTERACT%PAIR_RNA)) then
!           icalc(CALC%PAIR_RNA, iunit, junit) = 1
!        endif
!        if ((iunit == junit) .AND. (iclass_unit(iunit) == CLASS%RNA)) then
!           icalc(CALC%STACK_RNA, iunit, junit) = 1
!        endif
!        if (inmisc%flag_nlocal_unit(iunit, junit, INTERACT%AICG1)) then  !AICG
!           icalc(CALC%AICG1, iunit, junit) = 1
!        endif
!        if (inmisc%flag_nlocal_unit(iunit, junit, INTERACT%AICG2)) then  !AICG
!           icalc(CALC%AICG2, iunit, junit) = 1
!        endif
!        if (inmisc%flag_nlocal_unit(iunit, junit, INTERACT%SASA)) then  !sasa
!           icalc(CALC%SASA, iunit, junit) = 1
!        endif
        if (inmisc%flag_nlocal_unit(iunit, junit, INTERACT%EXV_WCA)) then
           icalc(CALC%EXV_WCA, iunit, junit) = 1
        endif
        if (inmisc%flag_nlocal_unit(iunit, junit, INTERACT%EXV_DT15)) then
           icalc(CALC%EXV_DT15, iunit, junit) = 1
        endif
        if (inmisc%flag_nlocal_unit(iunit, junit, INTERACT%EXV_GAUSS)) then
           icalc(CALC%EXV_GAUSS, iunit, junit) = 1
        endif

     end do
  end do


  ! --------------------------------------------------------------------
  if( imp_l2g(1) /= 1 ) then
    isearch_con = lmp2con (imp_l2g(1)-1) + 1
    isearch_LJ  = lmp2LJ  (imp_l2g(1)-1) + 1
    isearch_wca = lmp2wca (imp_l2g(1)-1) + 1
!    isearch_morse  = lmp2morse(imp_l2g(1)-1) + 1
!    if (inmisc%class_flag(CLASS%RNA)) then
!       isearch_rna_bp = lmp2rna_bp(imp_l2g(1)-1) + 1
!       isearch_rna_st = lmp2rna_st(imp_l2g(1)-1) + 1
!    endif
  end if


!!$omp parallel
!!$omp do private(klen,ksta,kend,imp,iunit,jmp,junit,kmp,isearch_con, &
!!$omp&           
  do n = 0, nthreads-1
  klen=(nmp_l-1+nthreads)/nthreads
  ksta=1+klen*n
  kend=min(ksta+klen-1,nmp_l)

  istart = 1
  do imp_l = ksta, kend
     imp = imp_l2g(imp_l)
     iunit = imp2unit(imp)

     !write(*, *) 'neighbor_assign: lmp2neigh', lmp2neigh(imp_l-ksta+1,n)
     loop_lneigh: do inum = istart, lmp2neigh(imp_l-ksta+1,n)
        
        jmp = ineigh2mp(inum,n)
        junit = imp2unit(jmp)
        
        i_exvol = 1
!        i_sasa  = 1 !sasa
        ! -----------------------------------------------------------------
        ! go
        if(icalc(CALC%GO, iunit, junit) == 1) then
!        if(icalc(CALC%GO, iunit, junit) == 1 .OR. &
!           icalc(CALC%AICG1, iunit, junit) == 1 .OR. &
!           icalc(CALC%AICG2, iunit, junit) == 1) then ! AICG

           do icon = isearch_con, lmp2con(imp)
              kmp = icon2mp(2, icon)

              if(jmp < kmp) exit

              if(jmp == kmp) then
                 isearch_con = icon + 1
!                 cycle loop_lneigh
                 if(coef_go(icon) > ZERO_JUDGE) then
                    i_exvol = 0
                 end if
              end if
           end do
        end if

        ! -----------------------------------------------------------------
        ! LJ
        if(icalc(CALC%LJ, iunit, junit) == 1) then

           do iLJ = isearch_LJ, lmp2LJ(imp)
              kmp = iLJ2mp(2, iLJ)

              if(jmp < kmp) exit

              if(jmp == kmp) then
                 isearch_LJ = iLJ + 1
!                 cycle loop_lneigh
                 if(coef_LJ(iLJ) > ZERO_JUDGE) then
                    i_exvol = 0
                 end if
              end if
           end do
        end if

        ! -----------------------------------------------------------------
        ! wca
        if(icalc(CALC%WCA, iunit, junit) == 1) then

           do iwca = isearch_wca, lmp2wca(imp)
              kmp = iwca2mp(2, iwca)

              if(jmp < kmp) exit

              if(jmp == kmp) then
                 isearch_wca = iwca + 1
!                 cycle loop_lneigh
                 if(coef_wca(iwca,1) > ZERO_JUDGE .or. coef_wca(iwca,2) > ZERO_JUDGE) then
                    i_exvol = 0
                 end if
              end if
           end do
        end if

!        ! -----------------------------------------------------------------
!        ! morse
!        if(icalc(CALC%MORSE, iunit, junit) == 1) then
!           do icon = isearch_morse, lmp2morse(imp)
!              kmp = imorse2mp(2, icon)
!
!              if(jmp < kmp) exit
!
!              if(jmp == kmp) then
!                 isearch_morse = icon + 1
!!                 cycle loop_lneigh
!                 if(coef_morse_a(icon) > ZERO_JUDGE .and. coef_morse_fD(icon) > ZERO_JUDGE) then
!                    i_exvol = 0
!                 end if
!              end if
!           end do
!        end if

!        ! -----------------------------------------------------------------
!        ! RNA base pairing
!        if(icalc(CALC%PAIR_RNA, iunit, junit) == 1) then
!           do icon = isearch_rna_bp, lmp2rna_bp(imp)
!              kmp = irna_bp2mp(2, icon)
!
!              if(jmp < kmp) exit
!
!              if(jmp == kmp) then
!                 isearch_rna_bp = icon + 1
!!                 cycle loop_lneigh
!                 if(coef_rna_bp(icon) > ZERO_JUDGE .or. (coef_rna_bp_a(icon) > ZERO_JUDGE .and. coef_rna_bp_fD(icon) > ZERO_JUDGE)) then
!                    i_exvol = 0
!                 end if
!                 i_exvol = 0
!              end if
!           end do
!        end if
!
!        ! -----------------------------------------------------------------
!        ! RNA base stacking
!        if(icalc(CALC%STACK_RNA, iunit, junit) == 1) then
!           do icon = isearch_rna_st, lmp2rna_st(imp)
!              kmp = irna_st2mp(2, icon)
!
!              if(jmp < kmp) exit
!
!              if(jmp == kmp) then
!                 isearch_rna_st = icon + 1
!!                 cycle loop_lneigh
!                 if(coef_rna_st(icon) > ZERO_JUDGE .or. (coef_rna_st_a(icon) > ZERO_JUDGE .and. coef_rna_st_fD(icon) > ZERO_JUDGE)) then
!                    i_exvol = 0
!                 end if
!              end if
!           end do
!        end if

        ! -----------------------------------------------------------------
        ! exvol
        if(icalc(CALC%EXV12, iunit, junit) == 1) then
           if(iunit == junit) then
!              if (iclass_unit(iunit) == CLASS%RNA) then
!                 select case (imp2type(imp))
!                 case (MPTYPE%RNA_PHOS) !P
!                    isep_nlocal_rna = inrna%n_sep_nlocal_P
!                 case (MPTYPE%RNA_SUGAR)!S
!                    isep_nlocal_rna = inrna%n_sep_nlocal_S
!                 case (MPTYPE%RNA_BASE) !B 
!                    isep_nlocal_rna = inrna%n_sep_nlocal_B
!                 case default 
!                    isep_nlocal_rna = -1 ! to supress compiler warning
!                    error_message = 'Error: logical defect in neighbor_assign'
!                    call util_error(ERROR%STOP_ALL, error_message)
!                 endselect
!                 
!                 if (jmp < imp + isep_nlocal_rna) then
!!                    cycle loop_lneigh
!                    i_exvol = 0
!                 end if
!
!              else if (iclass_unit(iunit) == CLASS%LIG) then !explig
              if (iclass_unit(iunit) == CLASS%LIG) then !explig
                 if(ires_mp(imp) == ires_mp(jmp)) then
!                    cycle loop_lneigh
                    i_exvol = 0
                 end if

              else
                 if(jmp < imp + isep_nlocal) then
!                    cycle loop_lneigh
                    i_exvol = 0
                 end if

              endif
           end if ! (iunit==junit)

           if(i_exvol == 1 .or. inmisc%i_exv_all > 0) then
              iexv = iexv + 1
              iexv2mp_l(1, iexv) = imp 
              iexv2mp_l(2, iexv) = jmp
              iexv2mp_l(3, iexv) = E_TYPE%EXV12
!             cycle loop_lneigh
           end if
        end if
        
        ! -----------------------------------------------------------------
        ! exvol 6
        if(icalc(CALC%EXV6, iunit, junit) == 1) then
           if(iunit == junit) then
!              if (iclass_unit(iunit) == CLASS%RNA) then
!                 select case (imp2type(imp))
!                 case (MPTYPE%RNA_PHOS) !P
!                    isep_nlocal_rna = inrna%n_sep_nlocal_P
!                 case (MPTYPE%RNA_SUGAR)!S
!                    isep_nlocal_rna = inrna%n_sep_nlocal_S
!                 case (MPTYPE%RNA_BASE) !B 
!                    isep_nlocal_rna = inrna%n_sep_nlocal_B
!                 case default 
!                    isep_nlocal_rna = -1 ! to supress compiler warning
!                    error_message = 'Error: logical defect in neighbor_assign'
!                    call util_error(ERROR%STOP_ALL, error_message)
!                 endselect
!                 
!                 if (jmp < imp + isep_nlocal_rna) then
!!                    cycle loop_lneigh
!                    i_exvol = 0
!                 end if
!
!              else if (iclass_unit(iunit) == CLASS%LIG) then !explig
              if (iclass_unit(iunit) == CLASS%SOPSC) then !explig

                 d_res = abs(ires_mp(imp) - ires_mp(jmp))

                 ! BB and BB
                 if (imp2type(imp) == MPTYPE%SOPBB .and. imp2type(jmp) == MPTYPE%SOPBB) then
                    if (d_res < insopsc%n_sep_nlocal_B_B) then
                       i_exvol = 0
                    endif

                 ! SC and SC
                 else if (imp2type(imp) == MPTYPE%SOPSC .and. imp2type(jmp) == MPTYPE%SOPSC) then
                    if (d_res < insopsc%n_sep_nlocal_S_S) then
                       i_exvol = 0
                    endif

                 ! BS and SC
                 else
                    if (d_res < insopsc%n_sep_nlocal_B_S) then
                       i_exvol = 0
                    endif

                 endif

              else if (iclass_unit(iunit) == CLASS%LIG) then !explig
                 if(ires_mp(imp) == ires_mp(jmp)) then
!                    cycle loop_lneigh
                    i_exvol = 0
                 end if

              else
                 if(jmp < imp + isep_nlocal) then
!                    cycle loop_lneigh
                    i_exvol = 0
                 end if

              endif
           end if ! (iunit==junit)

           if(i_exvol == 1 .or. inmisc%i_exv_all > 0) then
              iexv = iexv + 1
              iexv2mp_l(1, iexv) = imp 
              iexv2mp_l(2, iexv) = jmp
              iexv2mp_l(3, iexv) = E_TYPE%EXV6

!             cycle loop_lneigh
           end if
        end if
        

        ! -----------------------------------------------------------------
        ! excluded volume (DTRNA)
        if(icalc(CALC%EXV_WCA, iunit, junit) == 1) then
           i_exv_wca = 1 
           if(iunit == junit) then
              if (iclass_unit(iunit) == CLASS%RNA) then
                 select case (imp2type(imp))
                 case (MPTYPE%RNA_PHOS) !P
                    isep_nlocal_rna = indtrna13%n_sep_nlocal_P
                 case (MPTYPE%RNA_SUGAR)!S
                    isep_nlocal_rna = indtrna13%n_sep_nlocal_S
                 case (MPTYPE%RNA_BASE) !B 
                    isep_nlocal_rna = indtrna13%n_sep_nlocal_B
                 case default 
                    isep_nlocal_rna = -1 ! to supress compiler warning
                    error_message = 'Error: logical defect in neighbor_assign'
                    call util_error(ERROR%STOP_ALL, error_message)
                 endselect
                 
                 if (jmp < imp + isep_nlocal_rna) then
                    i_exv_wca = 0
                 end if

              else
                 !if(jmp < imp + isep_nlocal) then
                 !   i_exvol = 0
                 !end if
                 error_message = 'Error: EXV_WCA is only for RNA currently, in neighbor_assign'
                 call util_error(ERROR%STOP_ALL, error_message)
              endif
           end if ! (iunit==junit)

           if(i_exv_wca == 1) then
              iexv = iexv + 1
              iexv2mp_l(1, iexv) = imp 
              iexv2mp_l(2, iexv) = jmp
              iexv2mp_l(3, iexv) = E_TYPE%EXV_WCA
           end if
        end if

        ! -----------------------------------------------------------------
        ! excluded volume (DTRNA)
        if(icalc(CALC%EXV_DT15, iunit, junit) == 1) then
           i_exv_dt15 = 0 
           if(iunit == junit) then
              i_exv_dt15 = 1 
              if (iclass_unit(iunit) == CLASS%RNA) then
                 select case (imp2type(imp))
                 case (MPTYPE%RNA_PHOS) !P
                    isep_nlocal_rna = indtrna%n_sep_nlocal_P
                 case (MPTYPE%RNA_SUGAR)!S
                    isep_nlocal_rna = indtrna%n_sep_nlocal_S
                 case (MPTYPE%RNA_BASE) !B 
                    isep_nlocal_rna = indtrna%n_sep_nlocal_B
                 case default 
                    isep_nlocal_rna = -1 ! to suppress compiler warning
                    error_message = 'Error: logical defect in neighbor_assign'
                    call util_error(ERROR%STOP_ALL, error_message)
                 endselect
                 
                 if (jmp < imp + isep_nlocal_rna) then
                    i_exv_dt15 = 0
                 end if

              else if (iclass_unit(iunit) == CLASS%ION) then
                 continue

              else if (iclass_unit(iunit) == CLASS%LIG) then
                 continue

              else
                 !if(jmp < imp + isep_nlocal) then
                 !   i_exvol = 0
                 !end if
                 error_message = 'Error: EXV_DT15 is only for RNA currently, in neighbor_assign'
                 call util_error(ERROR%STOP_ALL, error_message)
              endif

           elseif (iclass_unit(iunit) == CLASS%RNA .and. iclass_unit(junit) == CLASS%RNA) then 

              i_exv_dt15 = 1 

           elseif ((iclass_unit(iunit) == CLASS%RNA .and. iclass_unit(junit) == CLASS%ION) .OR. &
                   (iclass_unit(iunit) == CLASS%ION .and. iclass_unit(junit) == CLASS%RNA)) then

              i_exv_dt15 = 1 

              ! Semi explicit model
              ! Excluded volume is not computed for phosphate-Mg interactions,
              ! excepting in case phosphate do not have charge (often terminal).
              if (inmisc%i_dtrna_model == 2019) then
                 ! Phosphate - Mg
                 if (imp2type(imp) == MPTYPE%RNA_PHOS) then  !!! imp is phosphate
                    if (abs(coef_charge(lmp2charge(imp),grep)) > ZERO_JUDGE) then !  Phosphate charge is negative
                       i_exv_dt15 = 0
                    endif
                 else if (imp2type(jmp) == MPTYPE%RNA_PHOS) then  !!! jmp is phosphate
                    if (abs(coef_charge(lmp2charge(jmp),grep)) > ZERO_JUDGE) then !  Phosphate charge is negative
                       i_exv_dt15 = 0
                    endif
                 endif
              endif

           elseif ((iclass_unit(iunit) == CLASS%ION .and. iclass_unit(junit) == CLASS%LIG) .OR. &
                   (iclass_unit(iunit) == CLASS%LIG .and. iclass_unit(junit) == CLASS%ION)) then

              i_exv_dt15 = 1 

           else
              error_message = 'Error: EXV_DT15 is only for RNA currently, in neighbor_assign'
              call util_error(ERROR%STOP_ALL, error_message)
                
           end if ! (iunit==junit)

           if(i_exv_dt15 == 1) then
              iexv = iexv + 1
              iexv2mp_l(1, iexv) = imp 
              iexv2mp_l(2, iexv) = jmp
              iexv2mp_l(3, iexv) = E_TYPE%EXV_DT15
           end if
        end if
        

        ! -----------------------------------------------------------------
        ! excluded volume with Gaussian function
        if(icalc(CALC%EXV_GAUSS, iunit, junit) == 1) then
           i_exv_gauss = 1 
           if(iunit == junit) then
              if (jmp < imp + 1) then
                 i_exv_gauss = 0
              end if

           end if ! (iunit==junit)

           if(i_exv_gauss == 1) then
              iexv = iexv + 1
              iexv2mp_l(1, iexv) = imp 
              iexv2mp_l(2, iexv) = jmp
              iexv2mp_l(3, iexv) = E_TYPE%EXV_GAUSS
           end if
        end if

!        ! -----------------------------------------------------------------
!        ! SASA
!        if(icalc(CALC%SASA, iunit, junit) == 1) then
!           if (iclass_unit(iunit) /= CLASS%PRO .and. &
!               cmp2atom(imp) /= ' P  ' .and. cmp2atom(imp) /= ' O  ') i_sasa = 0
!           if (iclass_unit(junit) /= CLASS%PRO .and. &
!               cmp2atom(jmp) /= ' P  ' .and. cmp2atom(jmp) /= ' O  ') i_sasa = 0
!           if(i_sasa == 1) then
!              iexv = iexv + 1
!              iexv2mp_l(1, iexv) = imp
!              iexv2mp_l(2, iexv) = jmp
!              iexv2mp_l(3, iexv) = E_TYPE%SASA
!           end if
!        end if
        ! ------------------------------------------------------------------         
     end do loop_lneigh

     istart   = lmp2neigh(imp_l-ksta+1,n) + 1 
     isearch_con = lmp2con(imp_l2g(min(imp_l+1,nmp_l))-1) + 1
     isearch_LJ  = lmp2LJ (imp_l2g(min(imp_l+1,nmp_l))-1) + 1
     isearch_wca = lmp2wca(imp_l2g(min(imp_l+1,nmp_l))-1) + 1
!     isearch_morse = lmp2morse(imp_l2g(min(imp_l+1,nmp_l))-1) + 1
!     if (inmisc%class_flag(CLASS%RNA)) then
!        isearch_rna_bp= lmp2rna_bp(imp_l2g(min(imp_l+1,nmp_l))-1) + 1
!        isearch_rna_st= lmp2rna_st(imp_l2g(min(imp_l+1,nmp_l))-1) + 1
!     endif
  end do
  end do


  ! --------------------------------------------------------------------
#ifdef MPI_PAR2

#ifdef SHARE_NEIGH_PNL
  nexv_l = iexv

  call neighbor_sort(irep, nexv_l, iexv2mp_l, iexv2mp_l_sort)

  TIME_S( tmc_neighbor )

  call mpi_allgather(nexv_l   ,1,MPI_INTEGER, &
                     nexv_lall,1,MPI_INTEGER, &
                     mpi_comm_local,ierr)

  nexv = sum( nexv_lall(0:npar_mpi-1) )

  disp (0) = 0
  count(0) = 3*nexv_lall(0)
  do n = 1, npar_mpi-1
    disp (n) = disp(n-1) + 3*nexv_lall(n-1)
    count(n) = 3*nexv_lall(n)
  end do

  call mpi_allgatherv( iexv2mp_l_sort,3*nexv_l  ,MPI_INTEGER, &
                       iexv2mp_pre  ,count, disp,MPI_INTEGER, &
                       mpi_comm_local,ierr )

  TIME_E( tmc_neighbor )

  call neighbor_sort(irep, nexv, iexv2mp_pre, nexv_lall=nexv_lall)
#else
  nexv = iexv
  nexv_lall(:) = 0  ! NIS aza
  nexv_lall(0) = nexv

  call neighbor_sort(irep, nexv, iexv2mp_l, iexv2mp_pre)
  call neighbor_sort(irep, nexv, iexv2mp_pre, nexv_lall=nexv_lall)
#endif

#else
  nexv = iexv
  nexv_lall(:) = 0  ! NIS aza
  nexv_lall(0) = nexv

  call neighbor_sort(irep, nexv, iexv2mp_l, iexv2mp_pre)
  call neighbor_sort(irep, nexv, iexv2mp_pre, nexv_lall=nexv_lall)

#endif


  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !!!! for exv2para(1:3, iexv, irep)
  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  do iexv = 1, nexv

     if (iexv2mp(3, iexv, irep) == E_TYPE%EXV6) then
        
        imp = iexv2mp(1, iexv, irep)
        jmp = iexv2mp(2, iexv, irep)
 
        iunit = imp2unit(imp)
        junit = imp2unit(jmp)

        if (iclass_unit(iunit) == CLASS%SOPSC .and. iclass_unit(junit) == CLASS%SOPSC) then

           ! Sidechain - Sidechain
           if (imp2type(imp) == MPTYPE%SOPSC .and. imp2type(jmp) == MPTYPE%SOPSC) then
              sigma = exv_radius_mp(imp) + exv_radius_mp(jmp)

           ! Backbone - Sidechain
           else if (imp2type(imp) == MPTYPE%SOPBB .and. imp2type(jmp) == MPTYPE%SOPSC) then

              d_res = abs(ires_mp(imp) - ires_mp(jmp))

              if (d_res > 1) then
                 sigma = inexv%exv_rad_sopsc_BB_SC + exv_radius_mp(jmp)
              else
                 sigma = insopsc%exv_scale_B_S_ang * (inexv%exv_rad_sopsc_BB_SC + exv_radius_mp(jmp))
              endif

           ! Sidechain - Backbone
           else if (imp2type(imp) == MPTYPE%SOPSC .and. imp2type(jmp) == MPTYPE%SOPBB) then

              d_res = abs(ires_mp(imp) - ires_mp(jmp))

              if (d_res > 1) then
                 sigma = exv_radius_mp(imp) + inexv%exv_rad_sopsc_BB_SC
              else
                 sigma = insopsc%exv_scale_B_S_ang * (exv_radius_mp(imp) + inexv%exv_rad_sopsc_BB_SC)
              endif

           ! Backbone - Backbone
           else if (imp2type(imp) == MPTYPE%SOPBB .and. imp2type(jmp) == MPTYPE%SOPBB) then
              sigma = inexv%exv_rad_sopsc_BB_BB * 2

           else 
              error_message = 'Error: logical defect in neighbor_assign, imp2type of SOPSC'
              call util_error(ERROR%STOP_ALL, error_message)
           endif

           exv2para(1, iexv, irep) = (inexv%exv6_cutoff * sigma) ** 2
           exv2para(2, iexv, irep) = sigma ** 2
           exv2para(3, iexv, irep) = 1.0
            !exv2para(3, iexv, irep) = sqrt( exv_epsilon_mp(imp) * exv_epsilon_mp(jmp))

        else
           exv2para(1, iexv, irep) = (inpro%cutoff_exvol * inpro%cdist_rep6) ** 2
           exv2para(2, iexv, irep) = inpro%cdist_rep6 ** 2
           exv2para(3, iexv, irep) = inpro%crep6
        endif

#ifdef _DEBUG
        write(*,'(a,1x,i5,1x,i5,3(x1f9.4))') 'neighbor_assign exv2para:', imp,jmp, &
                      exv2para(1,iexv,irep), exv2para(2,iexv,irep), exv2para(3,iexv,irep)
#endif

     endif

  end do


  !&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&
  !&&&
  !&&&       CAUTION:  iexv2mp(3,iexv,irep) will be replaced by imirror (0 or 1)
  !&&&
  !&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&&

  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  !!!! for iexv2mp(3, iexv, irep)
  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  if(inperi%i_periodic == 1) then
!     call util_pbindex(iexv2mp, nexv, irep)
     do iexv = 1, nexv
        imp = iexv2mp(1, iexv, irep)
        jmp = iexv2mp(2, iexv, irep)
 
        vx(1:3) = pxyz_mp_rep(1:3, jmp, irep) - pxyz_mp_rep(1:3, imp, irep)
        
!        do ix = 1, 3
!           if(vx(ix) > inperi%psizeh(ix)) then
!           vx(ix) = vx(ix) - inperi%psize(ix)
!              imi(ix) = 1
!           else if(vx(ix) < -inperi%psizeh(ix)) then
!              !           vx(ix) = vx(ix) + inperi%psize(ix)
!              imi(ix) = 2
!           else
!              imi(ix) = 0
!           end if
!        end do
!        imirror = 9*imi(1) + 3*imi(2) + imi(3)

        call util_pbneighbor(vx, imirror)

        iexv2mp(3, iexv, irep) = imirror
     end do

  else
     iexv2mp(3, 1:nexv, irep) = 1

  end if

#ifdef _DEBUG
  write(6,*) '####### start neighbor_assign'
#endif

end subroutine neighbor_assign
