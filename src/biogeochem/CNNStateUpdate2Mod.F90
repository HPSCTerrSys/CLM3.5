#include <misc.h>
#include <preproc.h>

module CNNStateUpdate2Mod

!-----------------------------------------------------------------------
!BOP
!
! !MODULE: NStateUpdate2Mod
!
! !DESCRIPTION:
! Module for nitrogen state variable update, mortality fluxes.
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
    public:: NStateUpdate2
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
! !IROUTINE: NStateUpdate2
!
! !INTERFACE:
subroutine NStateUpdate2(num_soilc, filter_soilc, num_soilp, filter_soilp)
!
! !DESCRIPTION:
! On the radiation time step, update all the prognostic nitrogen state
! variables affected by gap-phase mortality fluxes
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
   real(r8), pointer :: m_deadcrootn_storage_to_litr1n(:)
   real(r8), pointer :: m_deadcrootn_to_cwdn(:)
   real(r8), pointer :: m_deadcrootn_xfer_to_litr1n(:)
   real(r8), pointer :: m_deadstemn_storage_to_litr1n(:)
   real(r8), pointer :: m_deadstemn_to_cwdn(:)
   real(r8), pointer :: m_deadstemn_xfer_to_litr1n(:)
   real(r8), pointer :: m_frootn_storage_to_litr1n(:)
   real(r8), pointer :: m_frootn_to_litr1n(:)
   real(r8), pointer :: m_frootn_to_litr2n(:)
   real(r8), pointer :: m_frootn_to_litr3n(:)
   real(r8), pointer :: m_frootn_xfer_to_litr1n(:)
   real(r8), pointer :: m_leafn_storage_to_litr1n(:)
   real(r8), pointer :: m_leafn_to_litr1n(:)
   real(r8), pointer :: m_leafn_to_litr2n(:)
   real(r8), pointer :: m_leafn_to_litr3n(:)
   real(r8), pointer :: m_leafn_xfer_to_litr1n(:)
   real(r8), pointer :: m_livecrootn_storage_to_litr1n(:)
   real(r8), pointer :: m_livecrootn_to_cwdn(:)
   real(r8), pointer :: m_livecrootn_xfer_to_litr1n(:)
   real(r8), pointer :: m_livestemn_storage_to_litr1n(:)
   real(r8), pointer :: m_livestemn_to_cwdn(:)
   real(r8), pointer :: m_livestemn_xfer_to_litr1n(:)
   real(r8), pointer :: m_retransn_to_litr1n(:)
   real(r8), pointer :: m_deadcrootn_storage_to_litter(:)
   real(r8), pointer :: m_deadcrootn_to_litter(:)
   real(r8), pointer :: m_deadcrootn_xfer_to_litter(:)
   real(r8), pointer :: m_deadstemn_storage_to_litter(:)
   real(r8), pointer :: m_deadstemn_to_litter(:)
   real(r8), pointer :: m_deadstemn_xfer_to_litter(:)
   real(r8), pointer :: m_frootn_storage_to_litter(:)
   real(r8), pointer :: m_frootn_to_litter(:)
   real(r8), pointer :: m_frootn_xfer_to_litter(:)
   real(r8), pointer :: m_leafn_storage_to_litter(:)
   real(r8), pointer :: m_leafn_to_litter(:)
   real(r8), pointer :: m_leafn_xfer_to_litter(:)
   real(r8), pointer :: m_livecrootn_storage_to_litter(:)
   real(r8), pointer :: m_livecrootn_to_litter(:)
   real(r8), pointer :: m_livecrootn_xfer_to_litter(:)
   real(r8), pointer :: m_livestemn_storage_to_litter(:)
   real(r8), pointer :: m_livestemn_to_litter(:)
   real(r8), pointer :: m_livestemn_xfer_to_litter(:)
   real(r8), pointer :: m_retransn_to_litter(:)
!
! local pointers to implicit in/out scalars
   real(r8), pointer :: cwdn(:)               ! (gN/m2) coarse woody debris N
   real(r8), pointer :: litr1n(:)             ! (gN/m2) litter labile N
   real(r8), pointer :: litr2n(:)             ! (gN/m2) litter cellulose N
   real(r8), pointer :: litr3n(:)             ! (gN/m2) litter lignin N
   real(r8), pointer :: deadcrootn(:)         ! (gN/m2) dead coarse root N
   real(r8), pointer :: deadcrootn_storage(:) ! (gN/m2) dead coarse root N storage
   real(r8), pointer :: deadcrootn_xfer(:)    ! (gN/m2) dead coarse root N transfer
   real(r8), pointer :: deadstemn(:)          ! (gN/m2) dead stem N
   real(r8), pointer :: deadstemn_storage(:)  ! (gN/m2) dead stem N storage
   real(r8), pointer :: deadstemn_xfer(:)     ! (gN/m2) dead stem N transfer
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
   real(r8), pointer :: retransn(:)           ! (gN/m2) plant pool of retranslocated N
!
! local pointers to implicit out scalars
!
!
! !OTHER LOCAL VARIABLES:
   integer :: c,p         ! indices
   integer :: fp,fc       ! lake filter indices
   integer :: dtime       ! time step (s)
   real(r8):: dt          ! radiation time step (seconds)

!EOP
!-----------------------------------------------------------------------
    ! assign local pointers at the column level
    m_deadcrootn_storage_to_litr1n => clm3%g%l%c%cnf%m_deadcrootn_storage_to_litr1n
    m_deadcrootn_to_cwdn           => clm3%g%l%c%cnf%m_deadcrootn_to_cwdn
    m_deadcrootn_xfer_to_litr1n    => clm3%g%l%c%cnf%m_deadcrootn_xfer_to_litr1n
    m_deadstemn_storage_to_litr1n  => clm3%g%l%c%cnf%m_deadstemn_storage_to_litr1n
    m_deadstemn_to_cwdn            => clm3%g%l%c%cnf%m_deadstemn_to_cwdn
    m_deadstemn_xfer_to_litr1n     => clm3%g%l%c%cnf%m_deadstemn_xfer_to_litr1n
    m_frootn_storage_to_litr1n     => clm3%g%l%c%cnf%m_frootn_storage_to_litr1n
    m_frootn_to_litr1n             => clm3%g%l%c%cnf%m_frootn_to_litr1n
    m_frootn_to_litr2n             => clm3%g%l%c%cnf%m_frootn_to_litr2n
    m_frootn_to_litr3n             => clm3%g%l%c%cnf%m_frootn_to_litr3n
    m_frootn_xfer_to_litr1n        => clm3%g%l%c%cnf%m_frootn_xfer_to_litr1n
    m_leafn_storage_to_litr1n      => clm3%g%l%c%cnf%m_leafn_storage_to_litr1n
    m_leafn_to_litr1n              => clm3%g%l%c%cnf%m_leafn_to_litr1n
    m_leafn_to_litr2n              => clm3%g%l%c%cnf%m_leafn_to_litr2n
    m_leafn_to_litr3n              => clm3%g%l%c%cnf%m_leafn_to_litr3n
    m_leafn_xfer_to_litr1n         => clm3%g%l%c%cnf%m_leafn_xfer_to_litr1n
    m_livecrootn_storage_to_litr1n => clm3%g%l%c%cnf%m_livecrootn_storage_to_litr1n
    m_livecrootn_to_cwdn           => clm3%g%l%c%cnf%m_livecrootn_to_cwdn
    m_livecrootn_xfer_to_litr1n    => clm3%g%l%c%cnf%m_livecrootn_xfer_to_litr1n
    m_livestemn_storage_to_litr1n  => clm3%g%l%c%cnf%m_livestemn_storage_to_litr1n
    m_livestemn_to_cwdn            => clm3%g%l%c%cnf%m_livestemn_to_cwdn
    m_livestemn_xfer_to_litr1n     => clm3%g%l%c%cnf%m_livestemn_xfer_to_litr1n
    m_retransn_to_litr1n           => clm3%g%l%c%cnf%m_retransn_to_litr1n
    cwdn                           => clm3%g%l%c%cns%cwdn
    litr1n                         => clm3%g%l%c%cns%litr1n
    litr2n                         => clm3%g%l%c%cns%litr2n
    litr3n                         => clm3%g%l%c%cns%litr3n

    ! assign local pointers at the pft level
    m_deadcrootn_storage_to_litter => clm3%g%l%c%p%pnf%m_deadcrootn_storage_to_litter
    m_deadcrootn_to_litter         => clm3%g%l%c%p%pnf%m_deadcrootn_to_litter
    m_deadcrootn_xfer_to_litter    => clm3%g%l%c%p%pnf%m_deadcrootn_xfer_to_litter
    m_deadstemn_storage_to_litter  => clm3%g%l%c%p%pnf%m_deadstemn_storage_to_litter
    m_deadstemn_to_litter          => clm3%g%l%c%p%pnf%m_deadstemn_to_litter
    m_deadstemn_xfer_to_litter     => clm3%g%l%c%p%pnf%m_deadstemn_xfer_to_litter
    m_frootn_storage_to_litter     => clm3%g%l%c%p%pnf%m_frootn_storage_to_litter
    m_frootn_to_litter             => clm3%g%l%c%p%pnf%m_frootn_to_litter
    m_frootn_xfer_to_litter        => clm3%g%l%c%p%pnf%m_frootn_xfer_to_litter
    m_leafn_storage_to_litter      => clm3%g%l%c%p%pnf%m_leafn_storage_to_litter
    m_leafn_to_litter              => clm3%g%l%c%p%pnf%m_leafn_to_litter
    m_leafn_xfer_to_litter         => clm3%g%l%c%p%pnf%m_leafn_xfer_to_litter
    m_livecrootn_storage_to_litter => clm3%g%l%c%p%pnf%m_livecrootn_storage_to_litter
    m_livecrootn_to_litter         => clm3%g%l%c%p%pnf%m_livecrootn_to_litter
    m_livecrootn_xfer_to_litter    => clm3%g%l%c%p%pnf%m_livecrootn_xfer_to_litter
    m_livestemn_storage_to_litter  => clm3%g%l%c%p%pnf%m_livestemn_storage_to_litter
    m_livestemn_to_litter          => clm3%g%l%c%p%pnf%m_livestemn_to_litter
    m_livestemn_xfer_to_litter     => clm3%g%l%c%p%pnf%m_livestemn_xfer_to_litter
    m_retransn_to_litter           => clm3%g%l%c%p%pnf%m_retransn_to_litter
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
    retransn                       => clm3%g%l%c%p%pns%retransn

   ! set time steps
   dtime = get_step_size()
   dt = float(irad)*dtime

   ! column loop
!dir$ concurrent
!cdir nodep
   do fc = 1,num_soilc
      c = filter_soilc(fc)

      ! column-level nitrogen fluxes from gap-phase mortality

      ! leaf to litter
      litr1n(c) = litr1n(c) + m_leafn_to_litr1n(c) * dt
      litr2n(c) = litr2n(c) + m_leafn_to_litr2n(c) * dt
      litr3n(c) = litr3n(c) + m_leafn_to_litr3n(c) * dt

      ! fine root to litter
      litr1n(c) = litr1n(c) + m_frootn_to_litr1n(c) * dt
      litr2n(c) = litr2n(c) + m_frootn_to_litr2n(c) * dt
      litr3n(c) = litr3n(c) + m_frootn_to_litr3n(c) * dt

      ! wood to CWD
      cwdn(c) = cwdn(c) + m_livestemn_to_cwdn(c)  * dt
      cwdn(c) = cwdn(c) + m_deadstemn_to_cwdn(c)  * dt
      cwdn(c) = cwdn(c) + m_livecrootn_to_cwdn(c) * dt
      cwdn(c) = cwdn(c) + m_deadcrootn_to_cwdn(c) * dt

      ! retranslocated N pool to litter
      litr1n(c) = litr1n(c) + m_retransn_to_litr1n(c) * dt

      ! storage pools to litter
      litr1n(c) = litr1n(c) + m_leafn_storage_to_litr1n(c)      * dt
      litr1n(c) = litr1n(c) + m_frootn_storage_to_litr1n(c)     * dt
      litr1n(c) = litr1n(c) + m_livestemn_storage_to_litr1n(c)  * dt
      litr1n(c) = litr1n(c) + m_deadstemn_storage_to_litr1n(c)  * dt
      litr1n(c) = litr1n(c) + m_livecrootn_storage_to_litr1n(c) * dt
      litr1n(c) = litr1n(c) + m_deadcrootn_storage_to_litr1n(c) * dt

      ! transfer pools to litter
      litr1n(c) = litr1n(c) + m_leafn_xfer_to_litr1n(c)      * dt
      litr1n(c) = litr1n(c) + m_frootn_xfer_to_litr1n(c)     * dt
      litr1n(c) = litr1n(c) + m_livestemn_xfer_to_litr1n(c)  * dt
      litr1n(c) = litr1n(c) + m_deadstemn_xfer_to_litr1n(c)  * dt
      litr1n(c) = litr1n(c) + m_livecrootn_xfer_to_litr1n(c) * dt
      litr1n(c) = litr1n(c) + m_deadcrootn_xfer_to_litr1n(c) * dt

   end do ! end of column loop

   ! pft loop
!dir$ concurrent
!cdir nodep
   do fp = 1,num_soilp
      p = filter_soilp(fp)

      ! pft-level nitrogen fluxes from gap-phase mortality
      ! displayed pools
      leafn(p)      = leafn(p)      - m_leafn_to_litter(p)      * dt
      frootn(p)     = frootn(p)     - m_frootn_to_litter(p)     * dt
      livestemn(p)  = livestemn(p)  - m_livestemn_to_litter(p)  * dt
      deadstemn(p)  = deadstemn(p)  - m_deadstemn_to_litter(p)  * dt
      livecrootn(p) = livecrootn(p) - m_livecrootn_to_litter(p) * dt
      deadcrootn(p) = deadcrootn(p) - m_deadcrootn_to_litter(p) * dt
      retransn(p)   = retransn(p)   - m_retransn_to_litter(p)   * dt

      ! storage pools
      leafn_storage(p)      = leafn_storage(p)      - m_leafn_storage_to_litter(p)      * dt
      frootn_storage(p)     = frootn_storage(p)     - m_frootn_storage_to_litter(p)     * dt
      livestemn_storage(p)  = livestemn_storage(p)  - m_livestemn_storage_to_litter(p)  * dt
      deadstemn_storage(p)  = deadstemn_storage(p)  - m_deadstemn_storage_to_litter(p)  * dt
      livecrootn_storage(p) = livecrootn_storage(p) - m_livecrootn_storage_to_litter(p) * dt
      deadcrootn_storage(p) = deadcrootn_storage(p) - m_deadcrootn_storage_to_litter(p) * dt

      ! transfer pools
      leafn_xfer(p)      = leafn_xfer(p)      - m_leafn_xfer_to_litter(p)      * dt
      frootn_xfer(p)     = frootn_xfer(p)     - m_frootn_xfer_to_litter(p)     * dt
      livestemn_xfer(p)  = livestemn_xfer(p)  - m_livestemn_xfer_to_litter(p)  * dt
      deadstemn_xfer(p)  = deadstemn_xfer(p)  - m_deadstemn_xfer_to_litter(p)  * dt
      livecrootn_xfer(p) = livecrootn_xfer(p) - m_livecrootn_xfer_to_litter(p) * dt
      deadcrootn_xfer(p) = deadcrootn_xfer(p) - m_deadcrootn_xfer_to_litter(p) * dt

   end do

end subroutine NStateUpdate2
!-----------------------------------------------------------------------

end module CNNStateUpdate2Mod
