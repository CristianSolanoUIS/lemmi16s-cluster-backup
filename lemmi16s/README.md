# lemmi16s_v1

See [https://lemmi16s.ezlab.org/](https://lemmi16s.ezlab.org/) and [https://www.ezlab.org/lemmi16s-documentation.html](https://www.ezlab.org/lemmi16s-documentation.html)

In short:

```bash
git clone https://gitlab.com/ezlab/lemmi16s.git 
cd lemmi16s
git checkout tags/v1.0.1

export LEMMI16s_ROOT=/your/path/lemmi16s
export PATH=${LEMMI16s_ROOT}/workflow/scripts:$PATH

conda install -n base -c conda-forge mamba
mamba env update -n lemmi16s --file ${LEMMI16s_ROOT}/workflow/envs/lemmi16s.yaml
conda activate lemmi16s

lemmi16s --cores 8 # running locally on Docker
lemmi16s --cores 8 --use-singularity # running locally on Singularity
```
