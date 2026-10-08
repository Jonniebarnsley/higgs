# environment variables
export BISICLES_HOME=~/bisicles
export PETSC_DIR=$BISICLES_HOME/petsc
export FFTWDIR=$EBROOTFFTW

# amrfile
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:$BISICLES_HOME/master/code/libamrfile
export PYTHONPATH=$PYTHONPATH:$BISICLES_HOME/master/code/libamrfile/python/AMRFile

# filetools
export FILETOOLS=$BISICLES_HOME/master/code/filetools
alias extract='$FILETOOLS/extract2d.Linux.64.mpicxx.mpif90.OPT.MPI.PETSC.ex'
alias merge='$FILETOOLS/merge2d.Linux.64.mpicxx.mpif90.OPT.MPI.PETSC.ex'
alias flatten='$FILETOOLS/flatten2d.Linux.64.mpicxx.mpif90.OPT.MPI.PETSC.ex'
alias nctoamr='$FILETOOLS/nctoamr2d.Linux.64.mpicxx.mpif90.OPT.MPI.PETSC.ex'
