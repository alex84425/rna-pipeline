#!/bin/bash
#SBATCH --job-name=deseq-internal
#SBATCH --nodes=1
#SBATCH --mem=8000
#SBATCH --time=0-01:00:00
#SBATCH --mail-type=END

ml R

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -counts|--counts-Directory)
    COUNTS="$2"
    shift # past argument
    shift # past value
    ;;
    -results|--results-Directory)
    RESULTS="$2"
    shift # past argument
    shift # past value
    ;;
    -pipeDir|--pipeline-directory)
    PIPE_DIR="$2"
    shift # past argument
    shift # past value
    ;;
    --default)
    DEFAULT=YES
    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters



echo COUNTS        = "${COUNTS}"
echo RESULTS     = "${RESULTS}"
echo PIPE DIR = "${PIPE_DIR}"
echo DEFAULT         = "${DEFAULT}"

Rscript $PIPE_DIR/DESeq-analysis.R --countsDir $COUNTS --resultsDir $RESULTS


