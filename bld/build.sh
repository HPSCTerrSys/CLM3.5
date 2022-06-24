#!/bin/bash -e
# Set these env vars before running this script:
#  export SYSTEMNAME=
#  export MPI_LIB=
#  export MPI_INC=
#  export NETCDF_INC=
#  export NETCDF_LIB=
#  export NETCDF_MOD=
#  export OASIS_LIB=
#  export OASIS_INC=

# Set build parameters
CLM35_ROOT=$(git rev-parse --show-toplevel)
BUILD_DIR=${CLM35_ROOT}/$SYSTEMNAME/bld
INSTALL_DIR=${CLM35_ROOT}/$SYSTEMNAME/run
mkdir -p $BUILD_DIR
BUILD_LOG="$(dirname ${BUILD_DIR})/bld_log_$(date +%Y.%m.%d_%H.%M)"

# Configure
configure_cmd="./configure                              \
               -clm_bld ${BUILD_DIR}                    \
               -clm_exedir ${INSTALL_DIR}               \
               -fc mpif90                               \
               -cc mpicc                                \
               -mpi_lib ${MPI_LIB}                      \
               -mpi_inc ${MPI_INC}                      \
               -spmd                                    \
	       -smp                                     \
               -maxpft 1                                \
               -rtm off                                 \
               -usr_src usr.src                         \
               -oas3_pfl                                \
               -nc_inc ${NETCDF_INC}                    \
               -nc_lib ${NETCDF_LIB}                    \
               -nc_mod ${NETCDF_MOD}                    \
               -fflags -I${OASIS_INC}                   \
               -ldflags \"-lnetcdff                     \
                          ${OASIS_LIB}/libpsmile.MPI1.a \
                          ${OASIS_LIB}/libmct.a         \
                          ${OASIS_LIB}/libmpeu.a        \
                          ${OASIS_LIB}/libscrip.a\""

echo ${configure_cmd} | tee ${BUILD_LOG}
eval ${configure_cmd} 2>&1 | tee -a ${BUILD_LOG}

# Build
cd ${BUILD_DIR}
printf "\nBuilding CLM3.5 ...\n\n" | tee -a ${BUILD_LOG}
make -j16 2>&1 | tee -a ${BUILD_LOG}

# Check if CLM has been successfully installed
if [[ -f ${INSTALL_DIR}/clm ]]; then
  printf "\nSuccessfully installed CLM3.5 to ${INSTALL_DIR}/clm" | tee -a ${BUILD_LOG}
fi
printf "\nBuild log: ${BUILD_LOG}\n\n" | tee -a ${BUILD_LOG}
