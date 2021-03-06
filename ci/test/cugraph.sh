#!/bin/bash
set +e
set -x
export HOME=$WORKSPACE
export LIBCUDF_KERNEL_CACHE_PATH=${WORKSPACE}/.jitcache

# FIXME: "source activate" line should not be needed
source /opt/conda/bin/activate rapids

# Get datasets
cd /rapids/cugraph/datasets
bash ./get_test_data.sh
export RAPIDS_DATASET_ROOT_DIR=/rapids/cugraph/datasets

# Install test deps
conda install -y -c conda-forge -c defaults python-louvain networkx
# FIXME: Install the master version of dask, distributed, and streamz
pip install "git+https://github.com/dask/distributed.git" --upgrade --no-deps
pip install "git+https://github.com/dask/dask.git" --upgrade --no-deps
env
conda list

TESTRESULTS_DIR=${WORKSPACE}/testresults
mkdir -p ${TESTRESULTS_DIR}
SUITEERROR=0

# gtests
for gt in /rapids/cugraph/cpp/build/gtests/*_TEST; do
   # FIXME: remove this ASAP
   if [[ ${gt} == "/rapids/cugraph/cpp/build/gtests/SNMG_SPMV_TEST" ]]; then
      ${gt} --gtest_output=xml:${TESTRESULTS_DIR}/ --gtest_filter=-hibench_test/Tests_MGSpmv_hibench.CheckFP32_hibench*
      exitcode=$?
   else
      ${gt} --gtest_output=xml:${TESTRESULTS_DIR}/
      exitcode=$?
   fi
   if (( ${exitcode} != 0 )); then
      SUITEERROR=${exitcode}
      echo "FAILED: ${gt}"
   fi
done

# Python tests
py.test --junitxml=${TESTRESULTS_DIR}/pytest.xml -v /rapids/cugraph/python
exitcode=$?
if (( ${exitcode} != 0 )); then
   SUITEERROR=${exitcode}
   echo "FAILED: 1 or more tests in /rapids/cugraph/python"
fi

exit ${SUITEERROR}
