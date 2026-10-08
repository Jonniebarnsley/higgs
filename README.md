# Building BISICLES on Higgs

Instructions to build BISICLES on Higgs (Northumbria), including its third-party dependencies [Chombo 3.2](https://commons.lbl.gov/display/chombo/Chombo+-+Software+for+Adaptive+Solutions+of+Partial+Differential+Equations) and [PETSc](https://petsc.org/release/). Based on the official [BISICLES build instructions](https://davis.lbl.gov/Manuals/BISICLES-DOCS/readme.html).

Everything is built on the **foss/2025a** toolchain (GCC 14.2.0 + OpenMPI 5.0.7 + FlexiBLAS + FFTW). Every module must come from that same generation.

## Environment

Higgs' default `.bashrc` sources any scripts in `~/.bashrc.d/`. Create `~/.bashrc.d/bisicles.sh`:

```bash
# environment variables
export BISICLES_HOME=~/bisicles
export PETSC_DIR=$BISICLES_HOME/petsc

# amrfile
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$BISICLES_HOME/master/code/libamrfile
export PYTHONPATH=$PYTHONPATH:$BISICLES_HOME/master/code/libamrfile/python/AMRFile

# filetools
export FILETOOLS=$BISICLES_HOME/master/code/filetools
alias extract='$FILETOOLS/extract2d.Linux.64.mpicxx.mpif90.OPT.MPI.PETSC.ex'
alias merge='$FILETOOLS/merge2d.Linux.64.mpicxx.mpif90.OPT.MPI.PETSC.ex'
alias flatten='$FILETOOLS/flatten2d.Linux.64.mpicxx.mpif90.OPT.MPI.PETSC.ex'
alias nctoamr='$FILETOOLS/nctoamr2d.Linux.64.mpicxx.mpif90.OPT.MPI.PETSC.ex'
```

Aliases only work in interactive shells. In job scripts, use the full path, e.g. `$FILETOOLS/flatten2d.Linux.64.mpicxx.mpif90.OPT.MPI.PETSC.ex`.

```bash
source ~/.bashrc
```

## Load modules

Load these before every step below (PETSc, Chombo, BISICLES) and in every BISICLES job script:

```bash
module purge
module load foss/2025a HDF5/1.14.6-gompi-2025a netCDF/4.9.3-gompi-2025a Python/3.13.1-GCCcore-14.2.0
```

Loading HDF5 and netCDF prints Lmod warnings about `zlib`, `XZ`, `libxml2` and `binutils` being reloaded (e.g. `zlib/1.3.1 => zlib/1.3.1-GCCcore-14.2.0`). These are the same versions registered under two names on Higgs, so the warnings are harmless. What matters is that GCC, OpenMPI, FFTW and FlexiBLAS aren't swapped.

Sanity checks:

```bash
mpicxx --version                              # g++ 14.2.0
h5pcc -showconfig | grep -i "parallel hdf5"   # yes
nc-config --has-parallel4                     # yes
```

## Download source

```bash
mkdir -p $BISICLES_HOME/config
cd $BISICLES_HOME
git clone https://github.com/applied-numerical-algorithms-group-lbnl/Chombo_3.2.git Chombo
git clone https://github.com/ggslc/bisicles-uob.git master
git clone -b release https://gitlab.com/petsc/petsc.git petsc-src
```

This gives:

```
~/bisicles/
├── config/       # Higgs makefiles for Chombo and BISICLES
├── Chombo/
├── master/       # BISICLES
├── petsc-src/    # PETSc source
└── petsc/        # PETSc install (created below)
```

## PETSc install

Temporarily point `PETSC_DIR` at the source while configuring:

```bash
export PETSC_DIR=$BISICLES_HOME/petsc-src
cd $PETSC_DIR

./configure \
  --with-cc=mpicc --with-cxx=mpicxx --with-fc=mpif90 \
  --with-blaslapack-lib="-L$EBROOTFLEXIBLAS/lib -lflexiblas" \
  --download-hypre=yes \
  --with-debugging=0 COPTFLAGS="-O3 -march=znver4" CXXOPTFLAGS="-O3 -march=znver4" FOPTFLAGS="-O3 -march=znver4" \
  --with-x=0 --with-c2html=0 --with-ssl=0 \
  --prefix=$BISICLES_HOME/petsc
```

After a few minutes, configure ends with a `make PETSC_DIR=... PETSC_ARCH=arch-linux-c-opt all` line. Copy and run it. That build then prints a `make ... install` line, so run that too. Then set `PETSC_DIR` back:

```bash
export PETSC_DIR=$BISICLES_HOME/petsc
```

## Config files

Both makefiles live in `~/bisicles/config/` and are symlinked into place.

`~/bisicles/config/chombo-Make.defs.higgs`:

```make
# Chombo config for Higgs (foss/2025a)
MPI            = TRUE
OPT            = TRUE
DEBUG          = FALSE
USE_64         = TRUE

CXX            = g++
FC             = gfortran
MPICXX         = mpicxx
CH_CPP         = $(CXX) -E -P

cxxoptflags   += -march=znver4 -O2 -ftree-vectorize -ffast-math -funroll-loops -fPIC
foptflags     += -march=znver4 -O2 -ftree-vectorize -ffast-math -funroll-loops -fPIC
syslibflags   += -lgfortran -lm

USE_HDF        = TRUE
HDFINCFLAGS    = -I$(EBROOTHDF5)/include
HDFLIBFLAGS    = -L$(EBROOTHDF5)/lib -lhdf5 -lz
HDFMPIINCFLAGS = -I$(EBROOTHDF5)/include
HDFMPILIBFLAGS = -L$(EBROOTHDF5)/lib -lhdf5 -lz
```

`-march=znver4` targets the AMD EPYC 9654 CPUs, which are the same on the login and compute nodes. `$(EBROOTHDF5)` is set by the HDF5 module.

`~/bisicles/config/bisicles-Make.defs.higgs`:

```make
PYTHON_INC  = $(shell python3-config --includes)
PYTHON_LIBS = $(shell python3-config --ldflags --embed)

NETCDF_INC  = $(shell nc-config --cflags)
NETCDF_LIBS = $(shell nc-config --libs)

LIBFLAGS   += -L$(EBROOTFFTW)/lib -lfftw3

# FFTW, needed for the Bueler GIA model
FFTW_3      = TRUE
FFTWDIR     = $(EBROOTFFTW)
```

`$(EBROOTFFTW)` is set by the FFTW module, which `foss/2025a` loads.

### Symlinks

Use **absolute paths**. A relative symlink target is resolved from the link's own directory, not from where `ln` was run, so relative links end up broken.

```bash
# Chombo reads lib/mk/Make.defs.local
ln -sf $HOME/bisicles/config/chombo-Make.defs.higgs $HOME/bisicles/Chombo/lib/mk/Make.defs.local

# BISICLES reads code/mk/Make.defs.<hostname>, so link one per login node
for host in ln1 ln2; do
  ln -sf $HOME/bisicles/config/bisicles-Make.defs.higgs $HOME/bisicles/master/code/mk/Make.defs.$host
done
```

Check that the links resolve:

```bash
cat $HOME/bisicles/Chombo/lib/mk/Make.defs.local       # "No such file or directory" = broken link
cat $HOME/bisicles/master/code/mk/Make.defs.$(uname -n)
```

## Build BISICLES

Build the main executable, the [filetools](https://davis.lbl.gov/Manuals/BISICLES-DOCS/filetools.html), and the [amrfile](https://davis.lbl.gov/Manuals/BISICLES-DOCS/libamrfile.html) Python library:

```bash
cd $BISICLES_HOME/master/code/exec2D
make -j 8 all OPT=TRUE MPI=TRUE USE_PETSC=TRUE

cd $BISICLES_HOME/master/code/filetools
make -j 8 all OPT=TRUE MPI=TRUE USE_PETSC=TRUE

cd $BISICLES_HOME/master/code/libamrfile
make -j 8 libamrfile.so
```

This produces `driver2d.Linux.64.mpicxx.mpif90.OPT.MPI.PETSC.ex` in `exec2D/`, plus tools such as:

- `flatten`: converts BISICLES `.hdf5` (adaptive-mesh) output to evenly gridded netCDF
- `nctoamr`: converts netCDF to BISICLES-compatible `.hdf5`
- `extract`: extracts specified variables from a BISICLES output
- `merge`: merges BISICLES outputs

## Running

```bash
#!/bin/bash
#SBATCH --partition=cpu
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=96
#SBATCH --time=24:00:00

module purge
module load foss/2025a HDF5/1.14.6-gompi-2025a netCDF/4.9.3-gompi-2025a Python/3.13.1-GCCcore-14.2.0

srun $BISICLES_HOME/master/code/exec2D/driver2d.Linux.64.mpicxx.mpif90.OPT.MPI.PETSC.ex inputs.example
```

Use the `cpudebug` partition (1 hour limit) for quick tests.

## Other branches

To build a different BISICLES branch:

```bash
cd $BISICLES_HOME
git clone -b <branch_name> https://github.com/ggslc/bisicles-uob.git <branch_name>
for host in ln1 ln2; do
  ln -sf $HOME/bisicles/config/bisicles-Make.defs.higgs $HOME/bisicles/<branch_name>/code/mk/Make.defs.$host
done
```

Then repeat the build steps in `<branch_name>/code/`.
