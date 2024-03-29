!write_version
!> @brief Outputs version information.

subroutine write_version( lunout )

   implicit none

   integer, intent(in) :: lunout
   
   ! ##############################################
   ! These are supposed to be assigned in Makefile.
#ifdef VERGIT
   character(14), parameter :: VERSION_DATE = VERDATE
   character(7),  parameter :: VERSION_BUILD = VERBUILD
   character(30), parameter :: VERSION_BRANCH= VERBRANCH

   write(lunout, '(13a)', ADVANCE='no') '# Git commit '
   write(lunout, '(7a)' , ADVANCE='no') VERSION_BUILD
   write(lunout, '(9a)', ADVANCE='no') ' (branch:'
   write(lunout, '(30a)' , ADVANCE='no') trim(VERSION_BRANCH)
   write(lunout, '(14a)', ADVANCE='no') ') compiled on '
   write(lunout, '(14a)', ADVANCE='no') VERSION_DATE
   write(lunout, '(6a)'               ) ' (UTC)'

#else
! Subversion
#ifdef VERMAJOR
   integer, parameter :: VERSION_MAJOR = VERMAJOR
#else
   integer, parameter :: VERSION_MAJOR = 0
#endif
#ifdef VERMINOR
   integer, parameter :: VERSION_MINOR = VERMINOR
#else
   integer, parameter :: VERSION_MINOR = 0
#endif
#ifdef VERBUILD
   integer, parameter :: VERSION_BUILD = VERBUILD  
#else
   integer, parameter :: VERSION_BUILD = 0
#endif
   ! ##############################################

   write(lunout, '(a)',    ADVANCE='no') '# Version: '
   write(lunout, '(i1)',   ADVANCE='no') VERSION_MAJOR
   write(lunout, '(1a)',   ADVANCE='no') '.'
   write(lunout, '(i0.2)', ADVANCE='no') VERSION_MINOR
   write(lunout, '(1a)',   ADVANCE='no') '.'
   write(lunout, '(i0.4)'              ) VERSION_BUILD
#endif

endsubroutine write_version
