#!/usr/bin/env bash
#
# Written by Dave Tang
# Year 2023
#
set -euo pipefail

if [[ ! -x $(command -v gget) ]]; then
   >&2 echo "Could not find gget; is it installed?"
   exit 1
fi

script_dir=$(dirname $0)
max_procs=8
tmp_dir=/tmp
species=human
num_genes=100
version=$(cat ${script_dir}/.version)
keep=0
cluster_cols=0

usage(){
>&2 cat << EOF
Usage: $0
   [ -p | --max-procs INT (default 8) ]
   [ -t | --tmp-dir STR (default /tmp) ]
   [ -k | --keep keep tmp files ]
   [ -s | --species STR (default human) ]
   [ -n | --num-genes INT (default 100) ]
   [ -c | --cluster-cols ]
   [ -v | --version ]
   [ -h | --help ]
   <HGNC gene symbol>
EOF
exit 1
}

print_ver(){
   >&2 echo ${version}
   exit 0
}

args=$(getopt -a -o p:t:ks:n:vhc --long max-procs:,tmp-dir:,keep,species:,num-genes:,version,help,cluster-cols -- "$@")
if [[ $? -gt 0 ]]; then
  usage
fi

eval set -- ${args}
while :
do
  case $1 in
    -h | --help)         usage          ; shift   ;;
    -v | --version)      print_ver      ; shift   ;;
    -k | --keep)         keep=1         ; shift   ;;
    -c | --cluster-cols) cluster_cols=1 ; shift   ;;
    -p | --max-procs)    max_procs=$2   ; shift 2 ;;
    -s | --species)      species=$2     ; shift 2 ;;
    -n | --num-genes)    num_genes=$2   ; shift 2 ;;
    -t | --tmp-dir)      tmp_dir=$2     ; shift 2 ;;
    --) shift; break ;;
    *) >&2 echo Unsupported option: $1
       usage ;;
  esac
done

if [[ $# -eq 0 ]]; then
  usage
fi

out_dir=${tmp_dir}/$(whoami)_${RANDOM}
if [[ ! -d ${out_dir} ]]; then
   mkdir ${out_dir}
fi

gene=$1

cor_file=${gene}.cor
gget archs4 --csv --gene_count ${num_genes} ${gene} > ${out_dir}/${cor_file}
gget archs4 -s ${species} --csv -w tissue ${gene} > ${out_dir}/${gene}.csv

for g in $(cat ${out_dir}/${cor_file} | grep -v "^gene_symbol" | cut -f1 -d','); do
   echo ${g}
done \
   | xargs \
   -n 1 \
   -I{} \
   -P ${max_procs} \
   bash -c "gget archs4 -s ${species} --csv -w tissue {} > ${out_dir}/{}.csv"

if [[ ${cluster_cols} == 1 ]]; then
   ${script_dir}/heatmap.R --cluster_cols -m ${gene}_top${num_genes}.csv -o ${gene}_top${num_genes}.png ${out_dir}
else
   ${script_dir}/heatmap.R -m ${gene}_top${num_genes}.csv -o ${gene}_top${num_genes}.png ${out_dir}
fi

if [[ ${keep} == 0 ]]; then
   rm -rf ${out_dir}
fi

exit 0
