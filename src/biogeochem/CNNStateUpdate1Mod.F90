#include <misc.h>
#include <preproc.h>

module CNNStateUpdate1Mod

!-----------------------------------------------------------------------
!BOP
!
! !MODULE: NStateUpdate1Mod
!
! !DESCRIPTION:
! Module for nitrogen state variable updates, non-mortality fluxes.
!
! !USES:
    use shr_kind_mod, only: r8 => shr_kind_r8
    use clm_varcon  , only: istsoil
    use spmdMod     , only: masterproc
    use clm_varpar  , only: nlevsoi
    implicit none
    save
    private
! !PUBLIC MEMBER FUNCTIONS:
    public:: NStateUpdate1
!
! !REVISION HISTORY:
! 4/23/2004: Created by Peter Thornton
!
!EOP
!-----------------------------------------------------------------------

contains

!-----------------------------------------------------------------------
!BOP
!
! !IROUTINE: NStateUpdate1
!
! !INTERFACE:
subroutine NStateUpdate1(num_soilc, filter_soilc, num_soilp, filter_soilp)
!
! !DESCRIPTION:
! On the radiation time step, update all the prognostic nitrogen state
! variables (except for gap-phase mortality and fire fluxes)
!
! !USES:
   use clmtype
   use clm_varctl, only: irad
   use clm_time_manager, only: get_step_size
!
! !ARGUMENTS:
   implicit none
   integer, intent(in) :: num_soilc       ! number of soil columns in filter
   integer, intent(in) :: filter_soilc(:) ! filter for soil columns
   integer, intent(in) :: num_soilp       ! number of soil pfts in filter
   integer, intent(in) :: filter_soilp(:) ! filter for soil pfts
!
! !CALLED FROM:
! subroutine driver
!
! !REVISION HISTORY:
! 8/1/03: Created by Peter Thornton
!
! !LOCAL VARIABLES:
! local pointers to implicit in scalars
!
   integer , pointer :: ivt(:)         ! pft vegetation type
   real(r8), pointer :: woody(:)       ! binary flag for woody lifeform (1=woody, 0=not woody)
   real(r8), pointer :: cwdn_to_litr2n(:)
   real(r8), pointer :: cwdn_to_litr3n(:)
   real(r8), pointer :: frootn_to_litr1n(:)
   real(r8), pointer :: frootn_to_litr2n(:)
   real(r8), pointer :: frootn_to_litr3n(:)
   real(r8), pointer :: leafn_to_litr1n(:)
   real(r8), pointer :: leafn_to_litr2n(:)
   real(r8), pointer :: leafn_to_litr3n(:)
   real(r8), pointer :: litr1n_to_soil1n(:)
   real(r8), pointer :: litr2n_to_soil2n(:)
   real(r8), pointer :: litr3n_to_soil3n(:)
   real(r8), pointer :: ndep_to_sminn(:)
   real(r8), pointer :: nfix_to_sminn(:)
   real(r8), pointer :: sminn_to_denit_excess(:)
   real(r8), pointer :: sminn_to_denit_l1s1(:)
   real(r8), pointer :: sminn_to_denit_l2s2(:)
   real(r8), pointer :: sminn_to_denit_l3s3(:)
   real(r8), pointer :: sminn_to_denit_s1s2(:)
   real(r8), pointer :: sminn_to_denit_s2s3(:)
   real(r8), pointer :: sminn_to_denit_s3s4(:)
   real(r8), pointer :: sminn_to_denit_s4(:)
   real(r8), pointer :: sminn_to_plant(:)
   real(r8), pointer :: sminn_to_soil1n_l1(:)
   real(r8), pointer :: sminn_to_soil2n_l2(:)
   real(r8), pointer :: sminn_to_soil2n_s1(:)
   real(r8), pointer :: sminn_to_soil3n_l3(:)
   real(r8), pointer :: sminn_to_soil3n_s2(:)
   real(r8), pointer :: sminn_to_soil4n_s3(:)
   real(r8), pointer :: soil1n_to_soil2n(:)
   real(r8), pointer :: soil2n_to_soil3n(:)
   real(r8), pointer :: soil3n_to_soil4n(:)
   real(r8), pointer :: soil4n_to_sminn(:)
   real(r8), pointer :: supplement_to_sminn(:)
   real(r8), pointer :: deadcrootn_storage_to_xfer(:)
   real(r8), pointer :: deadcrootn_xfer_to_deadcrootn(:)
   real(r8), pointer :: deadstemn_storage_to_xfer(:)
   real(r8), pointer :: deadstemn_xfer_to_deadstemn(:)
   real(r8), pointer :: frootn_storage_to_xfer(:)
   real(r8), pointer :: frootn_to_litter(:)
   real(r8), pointer :: frootn_xfer_to_frootn(:)
   real(r8), pointer :: leafn_storage_to_xfer(:)
   real(r8), pointer :: leafn_to_litter(:)
   real(r8), pointer :: leafn_to_retransn(:)
   real(r8), pointer :: leafn_xfer_to_leafn(:)
   real(r8), pointer :: livecrootn_storage_to_xfer(:)
   real(r8), pointer :: livecrootn_to_deadcrootn(:)
   real(r8), pointer :: livecrootn_to_retransn(:)
   real(r8), pointer :: livecrootn_xfer_to_livecrootn(:)
   real(r8), pointer :: livestemn_storage_to_xfer(:)
   real(r8), pointer :: livestemn_to_deadstemn(:)
   real(r8), pointer :: livestemn_to_retransn(:)
   real(r8), pointer :: livestemn_xfer_to_livestemn(:)
   real(r8), pointer :: npool_to_deadcrootn(:)
   real(r8), pointer :: npool_to_deadcrootn_storage(:)
   real(r8), pointer :: npool_to_deadstemn(:)
   real(r8), pointer :: npool_to_deadstemn_storage(:)
   real(r8), pointer :: npool_to_frootn(:)
   real(r8), pointer :: npool_to_frootn_storage(:)
   real(r8), pointer :: npool_to_leafn(:)
   real(r8), pointer :: npool_to_leafn_storage(:)
   real(r8), pointer :: npool_to_livecrootn(:)
   real(r8), pointer :: npool_to_livecrootn_storage(:)
   real(r8), pointer :: npool_to_livestemn(:)
   real(r8), pointer :: npool_to_livestemn_storage(:)
   real(r8), pointer :: retransn_to_npool(:)
   real(r8), pointer :: sminn_to_npool(:)
!
! local pointers to implicit in/out scalars
   real(r8), pointer :: litr1n(:)             ! (gN/m2) litter labile N
   real(r8), pointer :: litr2n(:)             ! (gN/m2) litter cellulose N
   real(r8), pointer :: litr3n(:)             ! (gN/m2) litter lignin N
   real(r8), pointer :: sminn(:)              ! (gN/m2) soil mineral N
   real(r8), pointer :: soil1n(:)             ! (gN/m2) soil organic matter N (fast pool)
   real(r8), pointer :: soil2n(:)             ! (gN/m2) soil organic matter N (medium pool)
   real(r8), pointer :: soil3n(:)             ! (gN/m2) soil orgainc matter N (slow pool)
   real(r8), pointer :: soil4n(:)             ! (gN/m2) soil orgainc matter N (slowest pool)
   real(r8), pointer :: cwdn(:)               ! (gN/m2) coarse woody debris N
   real(r8), pointer :: frootn(:)             ! (gN/m2) fine root N
   real(r8), pointer :: frootn_storage(:)     ! (gN/m2) fine root N storage
   real(r8), pointer :: frootn_xfer(:)        ! (gN/m2) fine root N transfer
   real(r8), pointer :: leafn(:)              ! (gN/m2) leaf N
   real(r8), pointer :: leafn_storage(:)      ! (gN/m2) leaf N storage
   real(r8), pointer :: leafn_xfer(:)         ! (gN/m2) leaf N transfer
   real(r8), pointer :: livecrootn(:)         ! (gN/m2) live coarse root N
   real(r8), pointer :: livecrootn_storage(:) ! (gN/m2) live coarse root N storage
   real(r8), pointer :: livecrootn_xfer(:)    ! (gN/m2) live coarse root N transfer
   real(r8), pointer :: livestemn(:)          ! (gN/m2) live stem N
   real(r8), pointer :: livestemn_storage(:)  ! (gN/m2) live stem N storage
   real(r8), pointer :: livestemn_xfer(:)     ! (gN/m2) live stem N transfer
   real(r8), pointer :: deadcrootn(:)         ! (gN/m2) dead coarse root N
   real(r8), pointer :: deadcrootn_storage(:) ! (gN/m2) dead coarse root N storage
   real(r8), pointer :: deadcrootn_xfer(:)    ! (gN/m2) dead coarse root N transfer
   real(r8), pointer :: deadstemn(:)          ! (gN/m2) dead stem N
   real(r8), pointer :: deadstemn_storage(:)  ! (gN/m2) dead stem N storage
   real(r8), pointer :: deadstemn_xfer(:)     ! (gN/m2) dead stem N transfer
   real(r8), pointer :: retransn(:)           ! (gN/m2) plant pool of retranslocated N
   real(r8), pointer :: npool(:)              ! (gN/m2) temporary plant N pool
!
! local pointers to implicit out scalars
   real(r8), pointer :: col_begnb(:)   ! nitrogen mass, beginning of time step (gN/m**2)
   real(r8), pointer :: pft_begnb(:)   ! nitrogen mass, beginning of time step (gN/m**2)
!
! !OTHER LOCAL VARIABLES:
   integer :: c,p      ! indices
   integer :: fp,fc    ! lake filter indices
   integer :: dtime    ! time step (s)
   real(r8):: dt       ! radiation time step (seconds)

!EOP
!-----------------------------------------------------------------------
   ! assign local pointers
   woody                          => pftcon%woody

   ! assign local pointers at the column level
   cwdn_to_litr2n                 => clm3%g%l%c%cnf%cwdn_to_litr2n
   cwdn_to_litr3n                 => clm3%g%l%c%cnf%cwdn_to_litr3n
   frootn_to_litr1n               => clm3%g%l%c%cnf%frootn_to_litr1n
   frootn_to_litr2n               => clm3%g%l%c%cnf%frootn_to_litr2n
   frootn_to_litr3n               => clm3%g%l%c%cnf%frootn_to_litr3n
   leafn_to_litr1n                => clm3%g%l%c%cnf%leafn_to_litr1n
   leafn_to_litr2n                => clm3%g%l%c%cnf%leafn_to_litr2n
   leafn_to_litr3n                => clm3%g%l%c%cnf%leafn_to_litr3n
   litr1n_to_soil1n               => clm3%g%l%c%cnf%litr1n_to_soil1n
   litr2n_to_soil2n               => clm3%g%l%c%cnf%litr2n_to_soil2n
   litr3n_to_soil3n               => clm3%g%l%c%cnf%litr3n_to_soil3n
   ndep_to_sminn                  => clm3%g%l%c%cnf%ndep_to_sminn
   nfix_to_sminn                  => clm3%g%l%c%cnf%nfix_to_sminn
   sminn_to_denit_excess          => clm3%g%l%c%cnf%sminn_to_denit_excess
   sminn_to_denit_l1s1            => clm3%g%l%c%cnf%sminn_to_denit_l1s1
   sminn_to_denit_l2s2            => clm3%g%l%c%cnf%sminn_to_denit_l2s2
   sminn_to_denit_l3s3            => clm3%g%l%c%cnf%sminn_to_denit_l3s3
   sminn_to_denit_s1s2            => clm3%g%l%c%cnf%sminn_to_denit_s1s2
   sminn_to_denit_s2s3            => clm3%g%l%c%cnf%sminn_to_denit_s2s3
   sminn_to_denit_s3s4            => clm3%g%l%c%cnf%sminn_to_denit_s3s4
   sminn_to_denit_s4              => clm3%g%l%c%cnf%sminn_to_denit_s4
   sminn_to_plant                 => clm3%g%l%c%cnf%sminn_to_plant
   sminn_to_soil1n_l1             => clm3%g%l%c%cnf%sminn_to_soil1n_l1
   sminn_to_soil2n_l2             => clm3%g%l%c%cnf%sminn_to_soil2n_l2
   sminn_to_soil2n_s1             => clm3%g%l%c%cnf%sminn_to_soil2n_s1
   sminn_to_soil3n_l3             => clm3%g%l%c%cnf%sminn_to_soil3n_l3
   sminn_to_soil3n_s2             => clm3%g%l%c%cnf%sminn_to_soil3n_s2
   sminn_to_soil4n_s3             => clm3%g%l%c%cnf%sminn_to_soil4n_s3
   soil1n_to_soil2n               => clm3%g%l%c%cnf%soil1n_to_soil2n
   soil2n_to_soil3n               => clm3%g%l%c%cnf%soil2n_to_soil3n
   soil3n_to_soil4n               => clm3%g%l%c%cnf%soil3n_to_soil4n
   soil4n_to_sminn                => clm3%g%l%c%cnf%soil4n_to_sminn
   supplement_to_sminn            => clm3%g%l%c%cnf%supplement_to_sminn
   cwdn                           => clm3%g%l%c%cns%cwdn
   litr1n                         => clm3%g%l%c%cns%litr1n
   litr2n                         => clm3%g%l%c%cns%litr2n
   litr3n                         => clm3%g%l%c%cns%litr3n
   sminn                          => clm3%g%l%c%cns%sminn
   soil1n                         => clm3%g%l%c%cns%soil1n
   soil2n                         => clm3%g%l%c%cns%soil2n
   soil3n                         => clm3%g%l%c%cns%soil3n
   soil4n                         => clm3%g%l%c%cns%soil4n

   ! assign local pointers at the pft level
   ivt                            => clm3%g%l%c%p%itype
   deadcrootn_storage_to_xfer     => clm3%g%l%c%p%pnf%deadcrootn_storage_to_xfer
   deadcrootn_xfer_to_deadcrootn  => clm3%g%l%c%p%pnf%deadcrootn_xfer_to_deadcrootn
   deadstemn_storage_to_xfer      => clm3%g%l%c%p%pnf%deadstemn_storage_to_xfer
   deadstemn_xfer_to_deadstemn    => clm3%g%l%c%p%pnf%deadstemn_xfer_to_deadstemn
   frootn_storage_to_xfer         => clm3%g%l%c%p%pnf%frootn_storage_to_xfer
   frootn_to_litter               => clm3%g%l%c%p%pnf%frootn_to_litter
   frootn_xfer_to_frootn          => clm3%g%l%c%p%pnf%frootn_xfer_to_frootn
   leafn_storage_to_xfer          => clm3%g%l%c%p%pnf%leafn_storage_to_xfer
   leafn_to_litter                => clm3%g%l%c%p%pnf%leafn_to_litter
   leafn_to_retransn              => clm3%g%l%c%p%pnf%leafn_to_retransn
   leafn_xfer_to_leafn            => clm3%g%l%c%p%pnf%leafn_xfer_to_leafn
   livecrootn_storage_to_xfer     => clm3%g%l%c%p%pnf%livecrootn_storage_to_xfer
   livecrootn_to_deadcrootn       => clm3%g%l%c%p%pnf%livecrootn_to_deadcrootn
   livecrootn_to_retransn         => clm3%g%l%c%p%pnf%livecrootn_to_retransn
   livecrootn_xfer_to_livecrootn  => clm3%g%l%c%p%pnf%livecrootn_xfer_to_livecrootn
   livestemn_storage_to_xfer      => clm3%g%l%c%p%pnf%livestemn_storage_to_xfer
   livestemn_to_deadstemn         => clm3%g%l%c%p%pnf%livestemn_to_deadstemn
   livestemn_to_retransn          => clm3%g%l%c%p%pnf%livestemn_to_retransn
   livestemn_xfer_to_livestemn    => clm3%g%l%c%p%pnf%livestemn_xfer_to_livestemn
   npool_to_deadcrootn            => clm3%g%l%c%p%pnf%npool_to_deadcrootn
   npool_to_deadcrootn_storage    => clm3%g%l%c%p%pnf%npool_to_deadcrootn_storage
   npool_to_deadstemn             => clm3%g%l%c%p%pnf%npool_to_deadstemn
   npool_to_deadstemn_storage     => clm3%g%l%c%p%pnf%npool_to_deadstemn_storage
   npool_to_frootn                => clm3%g%l%c%p%pnf%npool_to_frootn
   npool_to_frootn_storage        => clm3%g%l%c%p%pnf%npool_to_frootn_storage
   npool_to_leafn                 => clm3%g%l%c%p%pnf%npool_to_leafn
   npool_to_leafn_storage         => clm3%g%l%c%p%pnf%npool_to_leafn_storage
   npool_to_livecrootn            => clm3%g%l%c%p%pnf%npool_to_livecrootn
   npool_to_livecrootn_storage    => clm3%g%l%c%p%pnf%npool_to_livecrootn_storage
   npool_to_livestemn             => clm3%g%l%c%p%pnf%npool_to_livestemn
   npool_to_livestemn_storage     => clm3%g%l%c%p%pnf%npool_to_livestemn_storage
   retransn_to_npool              => clm3%g%l%c%p%pnf%retransn_to_npool
   sminn_to_npool                 => clm3%g%l%c%p%pnf%sminn_to_npool
   deadcrootn                     => clm3%g%l%c%p%pns%deadcrootn
   deadcrootn_storage             => clm3%g%l%c%p%pns%deadcrootn_storage
   deadcrootn_xfer                => clm3%g%l%c%p%pns%deadcrootn_xfer
   deadstemn                      => clm3%g%l%c%p%pns%deadstemn
   deadstemn_storage              => clm3%g%l%c%p%pns%deadstemn_storage
   deadstemn_xfer                 => clm3%g%l%c%p%pns%deadstemn_xfer
   frootn                         => clm3%g%l%c%p%pns%frootn
   frootn_storage                 => clm3%g%l%c%p%pns%frootn_storage
   frootn_xfer                    => clm3%g%l%c%p%pns%frootn_xfer
   leafn                          => clm3%g%l%c%p%pns%leafn
   leafn_storage                  => clm3%g%l%c%p%pns%leafn_storage
   leafn_xfer                     => clm3%g%l%c%p%pns%leafn_xfer
   livecrootn                     => clm3%g%l%c%p%pns%livecrootn
   livecrootn_storage             => clm3%g%l%c%p%pns%livecrootn_storage
   livecrootn_xfer                => clm3%g%l%c%p%pns%livecrootn_xfer
   livestemn                      => clm3%g%l%c%p%pns%livestemn
   livestemn_storage              => clm3%g%l%c%p%pns%livestemn_storage
   livestemn_xfer                 => clm3%g%l%c%p%pns%livestemn_xfer
   npool                          => clm3%g%l%c%p%pns%npool
   retransn                       => clm3%g%l%c%p%pns%retransn

   ! set time steps
   dtime = get_step_size()
   dt = float(irad)*dtime

   ! column loop
!dir$ concurrent
!cdir nodep
   do fc = 1,num_soilc
      c = filter_soilc(fc)

      ! column-level fluxes

      ! N deposition and fixation
      sminn(c) = sminn(c) + ndep_to_sminn(c)*dt
      sminn(c) = sminn(c) + nfix_to_sminn(c)*dt

      ! plant to litter fluxes
      ! leaf litter
      litr1n(c) = litr1n(c) + leafn_to_litr1n(c)*dt
      litr2n(c) = litr2n(c) + leafn_to_litr2n(c)*dt
      litr3n(c) = litr3n(c) + leafn_to_litr3n(c)*dt
      ! fine root litter
      litr1n(c) = litr1n(c) + frootn_to_litr1n(c)*dt
      litr2n(c) = litr2n(c) + frootn_to_litr2n(c)*dt
      litr3n(c) = litr3n(c) + frootn_to_litr3n(c)*dt

      ! CWD to litter fluxes
      cwdn(c)   = cwdn(c)   - cwdn_to_litr2n(c)*dt
      litr2n(c) = litr2n(c) + cwdn_to_litr2n(c)*dt
      cwdn(c)   = cwdn(c)   - cwdn_to_litr3n(c)*dt
      litr3n(c) = litr3n(c) + cwdn_to_litr3n(c)*dt

      ! update litter states
      litr1n(c) = litr1n(c) - litr1n_to_soil1n(c)*dt
      litr2n(c) = litr2n(c) - litr2n_to_soil2n(c)*dt
      litr3n(c) = litr3n(c) - litr3n_to_soil3n(c)*dt

      ! update SOM states
      soil1n(c) = soil1n(c) + &
         (litr1n_to_soil1n(c) + sminn_to_soil1n_l1(c) - soil1n_to_soil2n(c))*dt
      soil2n(c) = soil2n(c) + &
         (litr2n_to_soil2n(c) + sminn_to_soil2n_l2(c) + &
          soil1n_to_soil2n(c) + sminn_to_soil2n_s1(c) - soil2n_to_soil3n(c))*dt
      soil3n(c) = soil3n(c) + &
         (litr3n_to_soil3n(c) + sminn_to_soil3n_l3(c) + &
          soil2n_to_soil3n(c) + sminn_to_soil3n_s2(c) - soil3n_to_soil4n(c))*dt
      soil4n(c) = soil4n(c) + &
         (soil3n_to_soil4n(c) + sminn_to_soil4n_s3(c) - soil4n_to_sminn(c))*dt

      ! immobilization/mineralization in litter-to-SOM and SOM-to-SOM fluxes
      sminn(c)  = sminn(c)  - &
         (sminn_to_soil1n_l1(c) + sminn_to_soil2n_l2(c) + &
          sminn_to_soil3n_l3(c) + sminn_to_soil2n_s1(c) + &
          sminn_to_soil3n_s2(c) + sminn_to_soil4n_s3(c) - &
          soil4n_to_sminn(c))*dt

      ! denitrification fluxes
      sminn(c) = sminn(c) - &
         (sminn_to_denit_l1s1(c) + sminn_to_denit_l2s2(c) + &
          sminn_to_denit_l3s3(c) + sminn_to_denit_s1s2(c) + &
          sminn_to_denit_s2s3(c) + sminn_to_denit_s3s4(c) + &
          sminn_to_denit_s4(c)   + sminn_to_denit_excess(c))*dt

      ! total plant uptake from mineral N
      sminn(c) = sminn(c) - sminn_to_plant(c)*dt

      ! flux that prevents N limitation (when SUPLN is set)
      sminn(c) = sminn(c) + supplement_to_sminn(c)*dt

   end do ! end of column loop

   ! pft loop
!dir$ concurrent
!cdir nodep
   do fp = 1,num_soilp
      p = filter_soilp(fp)

      ! phenology: transfer growth fluxes
      leafn(p)       = leafn(p)       + leafn_xfer_to_leafn(p)*dt
      leafn_xfer(p)  = leafn_xfer(p)  - leafn_xfer_to_leafn(p)*dt
      frootn(p)      = frootn(p)      + frootn_xfer_to_frootn(p)*dt
      frootn_xfer(p) = frootn_xfer(p) - frootn_xfer_to_frootn(p)*dt
      if (woody(ivt(p)) == 1.0_r8) then
          livestemn(p)       = livestemn(p)       + livestemn_xfer_to_livestemn(p)*dt
          livestemn_xfer(p)  = livestemn_xfer(p)  - livestemn_xfer_to_livestemn(p)*dt
          deadstemn(p)       = deadstemn(p)       + deadstemn_xfer_to_deadstemn(p)*dt
          deadstemn_xfer(p)  = deadstemn_xfer(p)  - deadstemn_xfer_to_deadstemn(p)*dt
          livecrootn(p)      = livecrootn(p)      + livecrootn_xfer_to_livecrootn(p)*dt
          livecrootn_xfer(p) = livecrootn_xfer(p) - livecrootn_xfer_to_livecrootn(p)*dt
          deadcrootn(p)      = deadcrootn(p)      + deadcrootn_xfer_to_deadcrootn(p)*dt
          deadcrootn_xfer(p) = deadcrootn_xfer(p) - deadcrootn_xfer_to_deadcrootn(p)*dt
      end if

      ! phenology: litterfall and retranslocation fluxes
      leafn(p)    = leafn(p)    - leafn_to_litter(p)*dt
      frootn(p)   = frootn(p)   - frootn_to_litter(p)*dt
      leafn(p)    = leafn(p)    - leafn_to_retransn(p)*dt
      retransn(p) = retransn(p) + leafn_to_retransn(p)*dt

      ! live wood turnover and retranslocation fluxes
      if (woody(ivt(p)) == 1._r8) then
          livestemn(p)  = livestemn(p)  - livestemn_to_deadstemn(p)*dt
          deadstemn(p)  = deadstemn(p)  + livestemn_to_deadstemn(p)*dt
          livestemn(p)  = livestemn(p)  - livestemn_to_retransn(p)*dt
          retransn(p)   = retransn(p)   + livestemn_to_retransn(p)*dt
          livecrootn(p) = livecrootn(p) - livecrootn_to_deadcrootn(p)*dt
          deadcrootn(p) = deadcrootn(p) + livecrootn_to_deadcrootn(p)*dt
          livecrootn(p) = livecrootn(p) - livecrootn_to_retransn(p)*dt
          retransn(p)   = retransn(p)   + livecrootn_to_retransn(p)*dt
      end if

      ! uptake from soil mineral N pool
      npool(p) = npool(p) + sminn_to_npool(p)*dt

      ! deployment from retranslocation pool
      npool(p)    = npool(p)    + retransn_to_npool(p)*dt
      retransn(p) = retransn(p) - retransn_to_npool(p)*dt

      ! allocation fluxes
      npool(p)           = npool(p)          - npool_to_leafn(p)*dt
      leafn(p)           = leafn(p)          + npool_to_leafn(p)*dt
      npool(p)           = npool(p)          - npool_to_leafn_storage(p)*dt
      leafn_storage(p)   = leafn_storage(p)  + npool_to_leafn_storage(p)*dt
      npool(p)           = npool(p)          - npool_to_frootn(p)*dt
      frootn(p)          = frootn(p)         + npool_to_frootn(p)*dt
      npool(p)           = npool(p)          - npool_to_frootn_storage(p)*dt
      frootn_storage(p)  = frootn_storage(p) + npool_to_frootn_storage(p)*dt
      if (woody(ivt(p)) == 1._r8) then
          npool(p)              = npool(p)              - npool_to_livestemn(p)*dt
          livestemn(p)          = livestemn(p)          + npool_to_livestemn(p)*dt
          npool(p)              = npool(p)              - npool_to_livestemn_storage(p)*dt
          livestemn_storage(p)  = livestemn_storage(p)  + npool_to_livestemn_storage(p)*dt
          npool(p)              = npool(p)              - npool_to_deadstemn(p)*dt
          deadstemn(p)          = deadstemn(p)          + npool_to_deadstemn(p)*dt
          npool(p)              = npool(p)              - npool_to_deadstemn_storage(p)*dt
          deadstemn_storage(p)  = deadstemn_storage(p)  + npool_to_deadstemn_storage(p)*dt
          npool(p)              = npool(p)              - npool_to_livecrootn(p)*dt
          livecrootn(p)         = livecrootn(p)         + npool_to_livecrootn(p)*dt
          npool(p)              = npool(p)              - npool_to_livecrootn_storage(p)*dt
          livecrootn_storage(p) = livecrootn_storage(p) + npool_to_livecrootn_storage(p)*dt
          npool(p)              = npool(p)              - npool_to_deadcrootn(p)*dt
          deadcrootn(p)         = deadcrootn(p)         + npool_to_deadcrootn(p)*dt
          npool(p)              = npool(p)              - npool_to_deadcrootn_storage(p)*dt
          deadcrootn_storage(p) = deadcrootn_storage(p) + npool_to_deadcrootn_storage(p)*dt
      end if

      ! move storage pools into transfer pools
      leafn_storage(p)  = leafn_storage(p)  - leafn_storage_to_xfer(p)*dt
      leafn_xfer(p)     = leafn_xfer(p)     + leafn_storage_to_xfer(p)*dt
      frootn_storage(p) = frootn_storage(p) - frootn_storage_to_xfer(p)*dt
      frootn_xfer(p)    = frootn_xfer(p)    + frootn_storage_to_xfer(p)*dt
      if (woody(ivt(p)) == 1._r8) then
          livestemn_storage(p)  = livestemn_storage(p)  - livestemn_storage_to_xfer(p)*dt
          livestemn_xfer(p)     = livestemn_xfer(p)     + livestemn_storage_to_xfer(p)*dt
          deadstemn_storage(p)  = deadstemn_storage(p)  - deadstemn_storage_to_xfer(p)*dt
          deadstemn_xfer(p)     = deadstemn_xfer(p)     + deadstemn_storage_to_xfer(p)*dt
          livecrootn_storage(p) = livecrootn_storage(p) - livecrootn_storage_to_xfer(p)*dt
          livecrootn_xfer(p)    = livecrootn_xfer(p)    + livecrootn_storage_to_xfer(p)*dt
          deadcrootn_storage(p) = deadcrootn_storage(p) - deadcrootn_storage_to_xfer(p)*dt
          deadcrootn_xfer(p)    = deadcrootn_xfer(p)    + deadcrootn_storage_to_xfer(p)*dt
      end if

   end do

end subroutine NStateUpdate1
!-----------------------------------------------------------------------

end module CNNStateUpdate1Mod
