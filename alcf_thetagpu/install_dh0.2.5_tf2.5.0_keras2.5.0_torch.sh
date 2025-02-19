#!/bin/bash

# As of June 30 2021
# This script will install (from scratch) XXXz223i/DeepHyperXXX keras, TensorFlow, and PyTorch on ThetaGPU
# 1 - Grab worker node interactively for 120 min (full-node queue)
# 2 - Run 'bash install_dh0.2.5_tf2.5.0_keras2.5.0_torch.sh'
# 3 - script installs everything down in $PWD/deephyper/...
# 4 - wait for it to complete

# unset *_TAG variables to build latest master
#DH_REPO_TAG="0.2.5"
DH_REPO_URL=https://github.com/z223i/deephyper.git

#TF_REPO_TAG="e5a6d2331b11e0e5e4b63a0d7257333ac8b8262a" # requires NumPy 1.19.x
#PT_REPO_TAG="v1.9.0"
#HOROVOD_REPO_TAG="v0.22.1" # v0.22.1 released on 2021-06-10 should be compatible with TF 2.6.x and 2.5.x
#HOROVOD_REPO_URL=https://github.com/uber/horovod.git
TF_REPO_URL=https://github.com/tensorflow/tensorflow.git
PT_REPO_URL=https://github.com/pytorch/pytorch.git

# where to install relative to current path
if [[ -z "$DH_REPO_TAG" ]]; then
    DH_INSTALL_SUBDIR='2021-06-30/'
else
    DH_INSTALL_SUBDIR=deephyper/${DH_REPO_TAG}
fi

# MPI source on ThetaGPU
MPI=/lus/theta-fs0/software/thetagpu/openmpi-4.0.5


# CUDA path and version information
CUDA_VERSION_MAJOR=11
CUDA_VERSION_MINOR=3
CUDA_VERSION=$CUDA_VERSION_MAJOR.$CUDA_VERSION_MINOR
CUDA_BASE=/usr/local/cuda-$CUDA_VERSION

CUDA_DEPS_BASE=/lus/theta-fs0/software/thetagpu/cuda

CUDNN_VERSION_MAJOR=8
CUDNN_VERSION_MINOR=2
CUDNN_VERSION_EXTRA=0.53
CUDNN_VERSION=$CUDNN_VERSION_MAJOR.$CUDNN_VERSION_MINOR.$CUDNN_VERSION_EXTRA
CUDNN_BASE=$CUDA_DEPS_BASE/cudnn-$CUDA_VERSION-linux-x64-v$CUDNN_VERSION

NCCL_VERSION_MAJOR=2
NCCL_VERSION_MINOR=9.9-1
NCCL_VERSION=$NCCL_VERSION_MAJOR.$NCCL_VERSION_MINOR
NCCL_BASE=$CUDA_DEPS_BASE/nccl_$NCCL_VERSION+cuda${CUDA_VERSION}_x86_64
# KGF: no Extended Compatibility in  NCCL
NCCL_BASE=$CUDA_DEPS_BASE/nccl_2.9.9-1+cuda11.0_x86_64

TENSORRT_VERSION_MAJOR=8
TENSORRT_VERSION_MINOR=0.0.3
TENSORRT_VERSION=$TENSORRT_VERSION_MAJOR.$TENSORRT_VERSION_MINOR
#TENSORRT_BASE=$CUDA_DEPS_BASE/TensorRT-$TENSORRT_VERSION.Ubuntu-18.04.x86_64-gnu.cuda-$CUDA_VERSION.cudnn$CUDNN_VERSION_MAJOR.$CUDNN_VERSION_MINOR
TENSORRT_BASE=$CUDA_DEPS_BASE/TensorRT-$TENSORRT_VERSION.Linux.x86_64-gnu.cuda-$CUDA_VERSION.cudnn$CUDNN_VERSION_MAJOR.$CUDNN_VERSION_MINOR

# TensorFlow Config flags (for ./configure run)
export TF_CUDA_COMPUTE_CAPABILITIES=8.0
export TF_CUDA_VERSION=$CUDA_VERSION_MAJOR
export TF_CUDNN_VERSION=$CUDNN_VERSION_MAJOR
export TF_TENSORRT_VERSION=$TENSORRT_VERSION_MAJOR
export TF_NCCL_VERSION=$NCCL_VERSION_MAJOR
export CUDA_TOOLKIT_PATH=$CUDA_BASE
export CUDNN_INSTALL_PATH=$CUDNN_BASE
export NCCL_INSTALL_PATH=$NCCL_BASE
export TENSORRT_INSTALL_PATH=$TENSORRT_BASE
export TF_NEED_OPENCL_SYCL=0
export TF_NEED_COMPUTECPP=0
export TF_CUDA_CLANG=0
export TF_NEED_OPENCL=0
export TF_NEED_MPI=0
export TF_NEED_ROCM=0
export TF_NEED_CUDA=1
export TF_NEED_TENSORRT=1
export TF_CUDA_PATHS=$CUDA_BASE,$CUDNN_BASE,$NCCL_BASE,$TENSORRT_BASE
export GCC_HOST_COMPILER_PATH=$(which gcc)
export CC_OPT_FLAGS="-march=native -Wno-sign-compare"
export TF_SET_ANDROID_WORKSPACE=0

# get the folder where this script is living
if [ -n "$ZSH_EVAL_CONTEXT" ]; then
    THISDIR=$( cd "$( dirname "$0" )" && pwd -LP)
else  # bash, sh, etc.
    THISDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -LP)
fi
# KGF: why use -LP here? Aren't the flags more or less contradictory?
# THISDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd -LP )

# set install path
DH_INSTALL_BASE_DIR=$THISDIR/$DH_INSTALL_SUBDIR
WHEEL_DIR=$DH_INSTALL_BASE_DIR/wheels

# confirm install path
echo On ThetaGPU $HOSTNAME
echo Installing module into $DH_INSTALL_BASE_DIR
#read -p "Are you sure? " -n 1 -r
#echo
#if [[ $REPLY =~ ^[Yy]$ ]]
#then
#    echo OK, you asked for it...
#else
#   exit -1
#fi


# Check for outside communication on ThetaGPU
# (be sure not to inherit these vars from dotfiles)
unset https_proxy
unset http_proxy

wget -q --spider -T 10 http://google.com
if [ $? -eq 0 ]; then
    echo "Network Online"
else
    # non-/interactive full-node job without --attrs=pubnet on ThetaGPU
    echo "Network Offline, setting proxy envs"
    export https_proxy=http://proxy.tmi.alcf.anl.gov:3128
    export http_proxy=http://proxy.tmi.alcf.anl.gov:3128
fi


# set Conda installation folder and where downloaded content will stay
CONDA_PREFIX_PATH=$DH_INSTALL_BASE_DIR/mconda3
DOWNLOAD_PATH=$DH_INSTALL_BASE_DIR/DOWNLOADS

mkdir -p $CONDA_PREFIX_PATH
mkdir -p $DOWNLOAD_PATH

# Download and install conda for a base python installation
CONDAVER=latest
CONDA_DOWNLOAD_URL=https://repo.continuum.io/miniconda
CONDA_INSTALL_SH=Miniconda3-$CONDAVER-Linux-x86_64.sh
echo Downloading miniconda installer
wget $CONDA_DOWNLOAD_URL/$CONDA_INSTALL_SH -P $DOWNLOAD_PATH
chmod +x $DOWNLOAD_PATH/$CONDA_INSTALL_SH

echo Installing Miniconda
$DOWNLOAD_PATH/$CONDA_INSTALL_SH -b -p $CONDA_PREFIX_PATH -u

cd $CONDA_PREFIX_PATH

# create a setup file
cat > setup.sh << EOF
preferred_shell=\$(basename \$SHELL)

if [ -n "\$ZSH_EVAL_CONTEXT" ]; then
    DIR=\$( cd "\$( dirname "\$0" )" && pwd )
else  # bash, sh, etc.
    DIR=\$( cd "\$( dirname "\${BASH_SOURCE[0]}" )" && pwd )
fi

eval "\$(\$DIR/bin/conda shell.\${preferred_shell} hook)"

# test network
unset https_proxy
unset http_proxy
wget -q --spider -T 10 http://google.com
if [ \$? -eq 0 ]; then
    echo "Network Online"
else
   echo "Network Offline, setting proxy envs"
   export https_proxy=http://proxy.tmi.alcf.anl.gov:3128
   export http_proxy=http://proxy.tmi.alcf.anl.gov:3128
fi

export LD_LIBRARY_PATH=$MPI/lib:$CUDA_BASE/lib64:$CUDNN_BASE/lib64:$NCCL_BASE/lib:$TENSORRT_BASE/lib
export PATH=$MPI/bin:\$PATH
EOF

# create custom pythonstart in local area to deal with python readlines error
cat > etc/pythonstart << EOF
# startup script for python to enable saving of interpreter history and
# enabling name completion

# import needed modules
import atexit
import os
#import readline
import rlcompleter

# where is history saved
historyPath = os.path.expanduser("~/.pyhistory")

# handler for saving history
def save_history(historyPath=historyPath):
    #import readline
    #try:
    #    readline.write_history_file(historyPath)
    #except:
    pass

# read history, if it exists
#if os.path.exists(historyPath):
#    readline.set_history_length(10000)
#    readline.read_history_file(historyPath)

# register saving handler
atexit.register(save_history)

# enable completion
#readline.parse_and_bind('tab: complete')

# cleanup
del os, atexit, rlcompleter, save_history, historyPath
EOF

cat > .condarc << EOF
env_prompt: "(\$ENV_NAME/\$CONDA_DEFAULT_ENV) "
pkgs_dirs:
   - \$HOME/.conda/pkgs
EOF

# move to base install directory
cd $DH_INSTALL_BASE_DIR

# setup conda environment
source $CONDA_PREFIX_PATH/setup.sh

# KGF: probably dont need a third (removed) network check--- proxy env vars inherited from either sourced setup.sh
# and/or first network check. Make sure "set+e" during above sourced setup.sh since the network check "wget" might
# return nonzero code if network is offline

echo CONDA BINARY: $(which conda)
echo CONDA VERSION: $(conda --version)
echo PYTHON VERSION: $(python --version)

cat > modulefile << EOF
#%Module2.0
## miniconda modulefile
##
proc ModulesHelp { } {
   puts stderr "This module will add Miniconda to your environment"
}

set _module_name  [module-info name]
set is_module_rm  [module-info mode remove]
set sys           [uname sysname]
set os            [uname release]
set HOME          $::env(HOME)

set CONDA_PREFIX                 $CONDA_PREFIX_PATH

setenv CONDA_PREFIX              \$CONDA_PREFIX
setenv PYTHONUSERBASE            \$HOME/.local/\${_module_name}
setenv ENV_NAME                  \$_module_name
setenv PYTHONSTARTUP             \$CONDA_PREFIX/etc/pythonstart

puts stdout "source \$CONDA_PREFIX/setup.sh"
module-whatis  "miniconda installation"
EOF

set -e

########
### Install TensorFlow
########

echo Conda install some dependencies


# Keras                    2.4.3
## Keras-Preprocessing      1.1.2

# six                      1.15.0
# tensorboard              2.5.0
# tensorboard-data-server  0.6.1
# tensorboard-plugin-wit   1.7.0
# tensorflow               2.4.0
# tensorflow-estimator     2.4.0
# torch                    1.9.0
# torch-tb-profiler        0.1.0
# torchvision              0.10.0


conda install keras==2.4.3
conda install tensorflow==2.4.0
conda install torch==1.9.0

#conda install -y cmake zip unzip ninja pyyaml mkl mkl-include setuptools cmake cffi typing_extensions future six requests dataclasses

# CUDA only: Add LAPACK support for the GPU if needed
conda install -y -c pytorch magma-cuda${CUDA_VERSION_MAJOR}${CUDA_VERSION_MINOR}

conda update -y pip
