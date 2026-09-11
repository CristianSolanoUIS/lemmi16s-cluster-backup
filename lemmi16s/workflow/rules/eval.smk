import glob
import shutil
import sys

import numpy as np
import pandas as pd
import toolbox
import yaml

root = toolbox.set_root()
tmp = toolbox.set_tmp(root, config)
os.chdir(tmp)

container_runner, docker_container, clean = toolbox.define_docker_command(
    "LEMMI16s_master", "lemmi16s_master",root, tmp, config, int(workflow.cores)
)


config["instance_name_nosuffix"] = config["instance_name"].split("___")[0]
try:
    suffix = "___" + config["instance_name"].split("___")[1]
except IndexError:
    suffix = ""

# load the yaml definintion of the sample
with open(
    "{}yaml/instances/{}.yaml".format(root, config["instance_name_nosuffix"]), "r"
) as file:
    sample_description = yaml.safe_load(file)

negative_samples    = []
calibration_samples = ["c{}".format(s) for s in sample_description["calibration"]]
evaluation_samples  = ["e{}".format(s) for s in sample_description["evaluation"]]

toolnames = set(
    [
        predictions_path.split("/")[-1].split(".")[0]
        for predictions_path in glob.glob(
            "{}analysis_outputs/*.{}*.predictions.tsv".format(
                root, config["instance_name_nosuffix"]
            )
        )
        if predictions_path.split("/")[-1].split(".")[0] not in config["no_evaluation"]
    ]
)

if not toolnames:
    sys.exit(f"[LEMMI16s Error] No predictions found in {root}analysis_outputs/ matching *.{config['instance_name_nosuffix']}*.predictions.tsv. Ensure analysis completed successfully before running evaluation.")


FILTERING_STEP = 3

#RESULT_DIR= config["tmp"]
#instance_name = config["instance_name"]
#TOOL = config["container"].split("/")[-1].split(":")[0]
#Database_name=config["Database"].split(':')[0]
Database_name=config["targets_taxonomy"].upper()
gcn_normalization = "no"
if config["gcn_normalization"] == 1:
  gcn_normalization = "yes"
#print(gcn_normalization)

localrules:
    target,

rule target:
    input:
        expand(
            "{root}evaluations/predictions.{toolname}.{all_sample}.{rank}.tsv",
            root=root,
            toolname=toolnames,
            all_sample=[
                "{}-{}".format(config["instance_name"], s)
                for s in negative_samples + calibration_samples + evaluation_samples
            ],
            rank=config["evaluation_taxlevel"],
        ),
        expand(
            "{root}evaluations/filtering_threshold.{toolname}.{instance_name}.{rank}.tsv",
            root=root,
            toolname=toolnames,
            instance_name=config["instance_name"],
            rank=config["evaluation_taxlevel"],
        ),
        expand(
            "{root}evaluations/precision.{toolname}.{evaluation_sample}.{rank}.tsv",
            root=root,
            toolname=toolnames,
            evaluation_sample=[
                "{}-{}".format(config["instance_name"], s) for s in evaluation_samples
            ],
            rank=config["evaluation_taxlevel"],
        ),
        expand(
            "{root}evaluations/tp.{toolname}.{evaluation_sample}.{rank}.tsv",
            root=root,
            toolname=toolnames,
            evaluation_sample=[
                "{}-{}".format(config["instance_name"], s) for s in evaluation_samples
            ],
            rank=config["evaluation_taxlevel"],
        ),
        expand(
            "{root}evaluations/fp.{toolname}.{evaluation_sample}.{rank}.tsv",
            root=root,
            toolname=toolnames,
            evaluation_sample=[
                "{}-{}".format(config["instance_name"], s) for s in evaluation_samples
            ],
            rank=config["evaluation_taxlevel"],
        ),
        expand(
            "{root}evaluations/l2.{toolname}.{evaluation_sample}.{rank}.tsv",
            root=root,
            toolname=toolnames,
            evaluation_sample=[
                "{}-{}".format(config["instance_name"], s) for s in evaluation_samples
            ],
            rank=config["evaluation_taxlevel"],
        ),
        expand(
            "{root}evaluations/f1.{toolname}.{evaluation_sample}.{rank}.tsv",
            root=root,
            toolname=toolnames,
            evaluation_sample=[
                "{}-{}".format(config["instance_name"], s) for s in evaluation_samples
            ],
            rank=config["evaluation_taxlevel"],
        ),
        expand(
            "{root}evaluations/recall.{toolname}.{evaluation_sample}.{rank}.tsv",
            root=root,
            toolname=toolnames,
            evaluation_sample=[
                "{}-{}".format(config["instance_name"], s) for s in evaluation_samples
            ],
            rank=config["evaluation_taxlevel"],
        ),
        expand(
            "{root}final_results/{instance_name}.f1.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.f1.json",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.precision.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.precision.json",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.tp.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.tp.json",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.fp.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.fp.json",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.recall.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.recall.json",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.l2.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.l2.json",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.memory_analysis.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.memory_analysis.json",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.runtime_analysis.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.runtime_analysis.json",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.filtering_threshold.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.filtering_threshold.json",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.auprc.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.auprc.json",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.prc.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.prc.json",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.memory_training.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.memory_training.json",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.runtime_training.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.runtime_training.json",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{toolname}.{all_sample}.{rank}.tsv",
            toolname=toolnames,
            all_sample=[
                "{}-{}".format(config["instance_name"], s)
                for s in evaluation_samples + calibration_samples + negative_samples
            ],
            rank=config["evaluation_taxlevel"],
            root=root,
        ),
        expand(
            "{root}final_results/{evaluation_samples}.json",
            toolname=toolnames,
            evaluation_samples=[
                "{}-{}".format(config["instance_name"], s) for s in evaluation_samples
            ],
            rank=config["evaluation_taxlevel"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.structure.json",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.ranks.json",
            instance_name=config["instance_name"],
            root=root,
        ),

rule predictions_by_ranks:
    input:
        predictions=expand(
            "{root}analysis_outputs/{{toolname}}.{{instance_name_nosuffix}}-{{all_sample}}.predictions.tsv",
            root=root,
        ),
        gnc_ref=expand(
            "{root}repository/{Database_name}/GCN_ref.tsv",
            root=root,
            Database_name=Database_name,
        ),
    output:
        expand(
            "{root}evaluations/predictions.{{toolname}}.{{instance_name_nosuffix}}{suffix}-{{all_sample}}.{{rank}}.tsv",
            root=root,
            suffix=suffix,
        ),
    wildcard_constraints:
        all_sample="(?!real_sample_).*",
    message:
        "Predictions at the given rank"
    threads: 1
    run:
        gcn=toolbox.GCN_reference(input.gnc_ref)
        toolbox.load_classified_reads_predictions(gcn,input.predictions[0], wildcards.rank, output[0],gcn_normalization)


rule define_thresholds:
    input:
        predictions_file=expand(
            "{root}evaluations/predictions.{{toolname}}.{calibration_sample}.{{rank}}.tsv",
            root=root,
            calibration_sample=[
                "{}-{}".format(config["instance_name"], s) for s in calibration_samples
            ],
        ),
        truth=expand(
            "{root}instances/{instance_name}/{calibration_sample}/queryTaxo.tsv",
            root=root,
            instance_name = config["instance_name_nosuffix"],
            calibration_sample=[
                "{}-{}".format(config["instance_name"], s) for s in calibration_samples
            ],
        ),
         
        gnc_ref=expand(
            "{root}repository/{Database_name}/GCN_ref.tsv",
            root=root,
            Database_name=Database_name,
        ),
    output:
        filtering_threshold=expand(
            "{root}evaluations/filtering_threshold.{{toolname}}.{{instance_name}}.{{rank}}.tsv",
            root=root,
        ),
        auprc=expand(
            "{root}evaluations/auprc.{{toolname}}.{{instance_name}}.{{rank}}.tsv",
            root=root,
        ),
        prc=expand(
            "{root}evaluations/prc.{{toolname}}.{{instance_name}}.{{rank}}.tsv",
            root=root,
        ),
    message:
        "Exploring the AUprC and defining the threshold to stay at the FDR..."
    threads: 1
    run:
        thresholds = []
        pr = []
        gcn=toolbox.GCN_reference(input.gnc_ref)
        for i, file in enumerate(input.predictions_file):
            truth = toolbox.load_truth_reads_predictions(
                gcn,
                input.truth[i],
                wildcards.rank,
                gcn_normalization,
            )

            predictions = pd.read_csv(file, header=1, sep="\t")
            #print(truth)
            #print(predictions)
            threshold = 0
            FDR_threshold = -1
            best_f1 = 0
            first_pass = True
            while True:
                precision = toolbox.get_precision(predictions, truth, threshold)
                recall = toolbox.get_recall(predictions, truth, threshold)
                if first_pass:
                    first_pass = False
                    # this is to close the line on the y axis side, recall if precision would be 0
                    pr.append((0, recall, i, threshold))
                f1 = toolbox.get_f1(predictions, truth, threshold)
                if len(pr) == 0 or (
                    len(pr) > 0 and pr[-1][0:3] != (precision, recall, i)
                ):
                    pr.append((precision, recall, i, threshold))
                if config["calibration_fdr"] != "best_f1":
                    if (FDR_threshold == -1) and (
                        1 - precision <= config["calibration_fdr"]
                    ):
                        FDR_threshold = threshold
                elif f1 > best_f1:
                    best_f1 = f1
                    FDR_threshold = threshold

                if precision == 1:
                    # this is to close the line on the x axis side, precision if recall would be 0
                    pr.append((1, 0, i, threshold))
                    break
                if recall == 0:
                    break
                threshold += FILTERING_STEP

            thresholds.append(FDR_threshold)

        with open(output.filtering_threshold[0], "w") as outp:
            if config["calibration_function"] == "mean":
                outp.write(str(int(np.average(thresholds))))
            elif config["calibration_function"] == "median":
                outp.write(str(int(np.median(thresholds))))
            else:
                outp.write(str(max(thresholds)))

        auprc = {}

        prev_x = 0
        prev_sample = None

        with open(output.prc[0], "w") as outp:
            for entry in pr:
                outp.write(
                    "{}\t{}\t{}\t{}\n".format(
                        input.predictions_file[entry[2]].split("/")[-1].split(".")[-3],
                        entry[0],
                        entry[1],
                        entry[3],
                    )
                )
                if (
                    prev_sample
                    == input.predictions_file[entry[2]].split("/")[-1].split(".")[-3]
                ):
                    x = entry[0] - prev_x
                else:
                    x = entry[0]
                prev_x = x
                prev_sample = (
                    input.predictions_file[entry[2]].split("/")[-1].split(".")[-3]
                )
                try:
                    auprc[
                        input.predictions_file[entry[2]].split("/")[-1].split(".")[-3]
                    ] += (x * entry[1])
                except KeyError:
                    auprc[
                        input.predictions_file[entry[2]].split("/")[-1].split(".")[-3]
                    ] = (x * entry[1])

        outp.close()

        with open(output.auprc[0], "w") as outp:
            for key in auprc:
                outp.write("{}\t{}\n".format(key, str(auprc[key])))

rule compute_precision:
    input:
        predictions_file=expand(
            "{root}evaluations/predictions.{{toolname}}.{{instance_name_nosuffix}}{suffix}-{{evaluation_sample}}.{{rank}}.tsv",
            root=root,
            suffix=suffix,
        ),
        truth=expand(
            "{root}instances/{instance_name}/{evaluation_sample}/queryTaxo.tsv",
            root=root,
            instance_name=config["instance_name"],
            evaluation_sample=[
                "{}-{}".format(config["instance_name"], s) for s in evaluation_samples
            ],
        ),
        filtering_threshold=expand(
            "{root}evaluations/filtering_threshold.{{toolname}}.{instance_name}.{{rank}}.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        gnc_ref=expand(
            "{root}repository/{Database_name}/GCN_ref.tsv",
            root=root,
            Database_name=Database_name,
        ),
    output:
        expand(
            "{root}evaluations/precision.{{toolname}}.{{instance_name_nosuffix}}{suffix}-{{evaluation_sample}}.{{rank}}.tsv",
            root=root,
            suffix=suffix,
        ),
    message:
        "Computing precision..."
    threads: 1
    run:
        with open(input.filtering_threshold[0]) as filtering_threshold_file:
            filtering_threshold = int(filtering_threshold_file.read())
        gcn=toolbox.GCN_reference(input.gnc_ref)
        truth = toolbox.load_truth_reads_predictions(
                gcn,
                input.truth[0],
                wildcards.rank,
                gcn_normalization
            )
        predictions = pd.read_csv(input.predictions_file[0], header=1, sep="\t")

        outp = open(output[0], "w")
        outp.write(str(toolbox.get_precision(predictions, truth, filtering_threshold)))
        outp.close()

rule compute_tp:
    input:
        predictions_file=expand(
            "{root}evaluations/predictions.{{toolname}}.{{instance_name_nosuffix}}{suffix}-{{evaluation_sample}}.{{rank}}.tsv",
            root=root,
            suffix=suffix,
        ),
        truth=expand(
            "{root}instances/{instance_name}/{evaluation_sample}/queryTaxo.tsv",
            root=root,
            instance_name = config["instance_name"],
            evaluation_sample=[
                "{}-{}".format(config["instance_name"], s) for s in evaluation_samples
            ],
        ),
        filtering_threshold=expand(
            "{root}evaluations/filtering_threshold.{{toolname}}.{instance_name}.{{rank}}.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        gnc_ref=expand(
            "{root}repository/{Database_name}/GCN_ref.tsv",
            root=root,
            Database_name=Database_name,
        ),
    output:
        expand(
            "{root}evaluations/tp.{{toolname}}.{{instance_name_nosuffix}}{suffix}-{{evaluation_sample}}.{{rank}}.tsv",
            root=root,
            suffix=suffix,
        ),
    message:
        "Computing tp..."
    threads: 1
    run:
        with open(input.filtering_threshold[0]) as filtering_threshold_file:
            filtering_threshold = int(filtering_threshold_file.read())
        gcn=toolbox.GCN_reference(input.gnc_ref)
        truth = toolbox.load_truth_reads_predictions(
                gcn,
                input.truth[0],
                wildcards.rank,
                gcn_normalization
            )

        predictions = pd.read_csv(input.predictions_file[0], header=1, sep="\t")

        outp = open(output[0], "w")
        outp.write(str(toolbox.get_tp(predictions, truth, filtering_threshold)))
        outp.close()

rule compute_fp:
    input:
        predictions_file=expand(
            "{root}evaluations/predictions.{{toolname}}.{{instance_name_nosuffix}}{suffix}-{{evaluation_sample}}.{{rank}}.tsv",
            root=root,
            suffix=suffix,
        ),
        truth=expand(
            "{root}instances/{instance_name}/{evaluation_sample}/queryTaxo.tsv",
            root=root,
            instance_name = config["instance_name"],
            evaluation_sample=[
                "{}-{}".format(config["instance_name"], s) for s in evaluation_samples
            ],
        ),
        filtering_threshold=expand(
            "{root}evaluations/filtering_threshold.{{toolname}}.{instance_name}.{{rank}}.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        gnc_ref=expand(
            "{root}repository/{Database_name}/GCN_ref.tsv",
            root=root,
            Database_name=Database_name,
        ),
    output:
        expand(
            "{root}evaluations/fp.{{toolname}}.{{instance_name_nosuffix}}{suffix}-{{evaluation_sample}}.{{rank}}.tsv",
            root=root,
            suffix=suffix,
        ),
    message:
        "Computing fp..."
    threads: 1
    run:
        with open(input.filtering_threshold[0]) as filtering_threshold_file:
            filtering_threshold = int(filtering_threshold_file.read())
        gcn=toolbox.GCN_reference(input.gnc_ref)
        truth = toolbox.load_truth_reads_predictions(
                gcn,
                input.truth[0],
                wildcards.rank,
                gcn_normalization
            )

        predictions = pd.read_csv(input.predictions_file[0], header=1, sep="\t")

        outp = open(output[0], "w")
        outp.write(str(toolbox.get_fp(predictions, truth, filtering_threshold)))
        outp.close()

rule compute_f1:
    input:
        predictions_file=expand(
            "{root}evaluations/predictions.{{toolname}}.{{instance_name_nosuffix}}{suffix}-{{evaluation_sample}}.{{rank}}.tsv",
            root=root,
            suffix=suffix,
        ),
        truth=expand(
            "{root}instances/{instance_name}/{evaluation_sample}/queryTaxo.tsv",
            root=root,
            instance_name = config["instance_name"],
            evaluation_sample=[
                "{}-{}".format(config["instance_name"], s) for s in evaluation_samples
            ],
        ),
        filtering_threshold=expand(
            "{root}evaluations/filtering_threshold.{{toolname}}.{instance_name}.{{rank}}.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        gnc_ref=expand(
            "{root}repository/{Database_name}/GCN_ref.tsv",
            root=root,
            Database_name=Database_name,
        ),
    output:
        expand(
            "{root}evaluations/f1.{{toolname}}.{{instance_name_nosuffix}}{suffix}-{{evaluation_sample}}.{{rank}}.tsv",
            root=root,
            suffix=suffix,
        ),
    message:
        "Computing f1..."
    threads: 1
    run:
        with open(input.filtering_threshold[0]) as filtering_threshold_file:
            filtering_threshold = int(filtering_threshold_file.read())
        gcn=toolbox.GCN_reference(input.gnc_ref)
        truth = toolbox.load_truth_reads_predictions(
                gcn,
                input.truth[0],
                wildcards.rank,
                gcn_normalization
            )

        predictions = pd.read_csv(input.predictions_file[0], header=1, sep="\t")

        outp = open(output[0], "w")
        outp.write(str(toolbox.get_f1(predictions, truth, filtering_threshold)))
        outp.close()


rule compute_l2:
    input:
        predictions_file=expand(
            "{root}evaluations/predictions.{{toolname}}.{{instance_name_nosuffix}}{suffix}-{{evaluation_sample}}.{{rank}}.tsv",
            root=root,
            suffix=suffix,
        ),
        truth=expand(
            "{root}instances/{instance_name}/{evaluation_sample}/queryTaxo.tsv",
            root=root,
            instance_name = config["instance_name"],
            evaluation_sample=[
                "{}-{}".format(config["instance_name"], s) for s in evaluation_samples
            ],
        ),
        filtering_threshold=expand(
            "{root}evaluations/filtering_threshold.{{toolname}}.{instance_name}.{{rank}}.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        gnc_ref=expand(
            "{root}repository/{Database_name}/GCN_ref.tsv",
            root=root,
            Database_name=Database_name,
        ),
    output:
        expand(
            "{root}evaluations/l2.{{toolname}}.{{instance_name_nosuffix}}{suffix}-{{evaluation_sample}}.{{rank}}.tsv",
            root=root,
            suffix=suffix,
        ),
    message:
        "Computing l2..."
    threads: 1
    run:
        with open(input.filtering_threshold[0]) as filtering_threshold_file:
            filtering_threshold = int(filtering_threshold_file.read())

        gcn=toolbox.GCN_reference(input.gnc_ref)
        truth = toolbox.load_truth_reads_predictions(
                gcn,
                input.truth[0],
                wildcards.rank,
                gcn_normalization
            )

        predictions = pd.read_csv(input.predictions_file[0], header=1, sep="\t")

        outp = open(output[0], "w")
        outp.write(str(toolbox.get_l2(predictions, truth, filtering_threshold)))
        outp.close()

rule compute_recall:
    input:
        predictions_file=expand(
            "{root}evaluations/predictions.{{toolname}}.{{instance_name_nosuffix}}{suffix}-{{evaluation_sample}}.{{rank}}.tsv",
            root=root,
            suffix=suffix,
        ),
        truth=expand(
            "{root}instances/{instance_name}/{evaluation_sample}/queryTaxo.tsv",
            root=root,
            instance_name = config["instance_name"],
            evaluation_sample=[
                "{}-{}".format(config["instance_name"], s) for s in evaluation_samples
            ],
        ),
        filtering_threshold=expand(
            "{root}evaluations/filtering_threshold.{{toolname}}.{instance_name}.{{rank}}.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        gnc_ref=expand(
            "{root}repository/{Database_name}/GCN_ref.tsv",
            root=root,
            Database_name=Database_name,
        ),
    output:
        expand(
            "{root}evaluations/recall.{{toolname}}.{{instance_name_nosuffix}}{suffix}-{{evaluation_sample}}.{{rank}}.tsv",
            root=root,
            suffix=suffix,
        ),
    message:
        "Computing recall..."
    threads: 1
    run:
        with open(input.filtering_threshold[0]) as filtering_threshold_file:
            filtering_threshold = int(filtering_threshold_file.read())
        gcn=toolbox.GCN_reference(input.gnc_ref)
        truth = toolbox.load_truth_reads_predictions(
                gcn,
                input.truth[0],
                wildcards.rank,
                gcn_normalization
            )

        predictions = pd.read_csv(input.predictions_file[0], header=1, sep="\t")

        outp = open(output[0], "w")
        outp.write(str(toolbox.get_recall(predictions, truth, filtering_threshold)))
        outp.close()

rule f1_to_final_table:
    input:
        data=expand(
            "{root}evaluations/f1.{toolname}.{evaluation_sample}.{rank}.tsv",
            root=root,
            toolname=toolnames,
            evaluation_sample=[
                "{}-{}".format(config["instance_name"], s) for s in evaluation_samples
            ],
            rank=config["evaluation_taxlevel"],
        ),
    output:
        expand(
            "{root}final_results/{instance_name}.f1.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.f1.json",
            instance_name=config["instance_name"],
            root=root,
        ),
    message:
        "Outputting the f1 table..."
    threads: 1
    run:
        dict_for_average = {}
        with open(output[0], "w") as outp:
            outp.write(
                "#LEMMI16s_dm:v1.0\ntoolname\tsample\trank\tvalue\n".format(
                    config["Database"]
                )
            )
            for file in input.data:
                toolname = file.split("/")[-1].split(".")[1]
                sample = file.split("/")[-1].split(".")[2]
                rank = file.split("/")[-1].split(".")[3]
                with open(file) as inp:
                    value = inp.read()
                outp.write("{}\t{}\t{}\t{}\n".format(toolname, sample, rank, value))
                # keep the value for average
                try:
                    dict_for_average[toolname][rank].append(value)
                except KeyError:
                    try:
                        dict_for_average[toolname][rank] = [value]
                    except KeyError:
                        dict_for_average[toolname] = {}
                        dict_for_average[toolname][rank] = [value]
            for key_toolname in dict_for_average:
                for key_rank in dict_for_average[key_toolname]:
                    outp.write(
                        "{}\t{}\t{}\t{}\n".format(
                            key_toolname,
                            config["instance_name"],
                            key_rank,
                            np.average(
                                [
                                    float(v)
                                    for v in dict_for_average[key_toolname][key_rank]
                                ]
                            ),
                        )
                    )
        toolbox.to_json(output[0], output[1], config=config, sort_with="self")

rule precision_to_final_table:
    input:
        data=expand(
            "{root}evaluations/precision.{toolname}.{evaluation_sample}.{rank}.tsv",
            root=root,
            toolname=toolnames,
            evaluation_sample=[
                "{}-{}".format(config["instance_name"], s) for s in evaluation_samples
            ],
            rank=config["evaluation_taxlevel"],
        ),
        sort=expand(
            "{root}final_results/{instance_name}.f1.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
    output:
        expand(
            "{root}final_results/{instance_name}.precision.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.precision.json",
            instance_name=config["instance_name"],
            root=root,
        ),
    message:
        "Outputting the precision table..."
    threads: 1
    run:
        dict_for_average = {}
        with open(output[0], "w") as outp:
            outp.write(
                "#LEMMI16_dm:v1.0\ntoolname\tsample\trank\tvalue\n".format(
                    config["Database"]
                )
            )
            for file in input.data:
                toolname = file.split("/")[-1].split(".")[1]
                sample = file.split("/")[-1].split(".")[2]
                rank = file.split("/")[-1].split(".")[3]
                with open(file) as inp:
                    value = inp.read()
                outp.write("{}\t{}\t{}\t{}\n".format(toolname, sample, rank, value))
                # keep the value for average
                try:
                    dict_for_average[toolname][rank].append(value)
                except KeyError:
                    try:
                        dict_for_average[toolname][rank] = [value]
                    except KeyError:
                        dict_for_average[toolname] = {}
                        dict_for_average[toolname][rank] = [value]
            for key_toolname in dict_for_average:
                for key_rank in dict_for_average[key_toolname]:
                    outp.write(
                        "{}\t{}\t{}\t{}\n".format(
                            key_toolname,
                            config["instance_name"],
                            key_rank,
                            np.average(
                                [
                                    float(v)
                                    for v in dict_for_average[key_toolname][key_rank]
                                ]
                            ),
                        )
                    )
        toolbox.to_json(output[0], output[1], config=config, sort_with=input.sort[0])

rule fp_to_final_table:
    input:
        data=expand(
            "{root}evaluations/fp.{toolname}.{evaluation_sample}.{rank}.tsv",
            root=root,
            toolname=toolnames,
            evaluation_sample=[
                "{}-{}".format(config["instance_name"], s) for s in evaluation_samples
            ],
            rank=config["evaluation_taxlevel"],
        ),
        sort=expand(
            "{root}final_results/{instance_name}.f1.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
    output:
        expand(
            "{root}final_results/{instance_name}.fp.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.fp.json",
            instance_name=config["instance_name"],
            root=root,
        ),
    message:
        "Outputting the fp table..."
    threads: 1
    run:
        dict_for_average = {}
        with open(output[0], "w") as outp:
            outp.write(
                "#LEMMI16s_dm:v1.0\ntoolname\tsample\trank\tvalue\n".format(
                    config["Database"]
                )
            )
            for file in input.data:
                toolname = file.split("/")[-1].split(".")[1]
                sample = file.split("/")[-1].split(".")[2]
                rank = file.split("/")[-1].split(".")[3]
                with open(file) as inp:
                    value = inp.read()
                outp.write("{}\t{}\t{}\t{}\n".format(toolname, sample, rank, value))
                # keep the value for average
                try:
                    dict_for_average[toolname][rank].append(value)
                except KeyError:
                    try:
                        dict_for_average[toolname][rank] = [value]
                    except KeyError:
                        dict_for_average[toolname] = {}
                        dict_for_average[toolname][rank] = [value]
            for key_toolname in dict_for_average:
                for key_rank in dict_for_average[key_toolname]:
                    outp.write(
                        "{}\t{}\t{}\t{}\n".format(
                            key_toolname,
                            config["instance_name"],
                            key_rank,
                            np.average(
                                [
                                    float(v)
                                    for v in dict_for_average[key_toolname][key_rank]
                                ]
                            ),
                        )
                    )
        toolbox.to_json(output[0], output[1], config=config, sort_with=input.sort[0])

rule tp_to_final_table:
    input:
        data=expand(
            "{root}evaluations/tp.{toolname}.{evaluation_sample}.{rank}.tsv",
            root=root,
            toolname=toolnames,
            evaluation_sample=[
                "{}-{}".format(config["instance_name"], s) for s in evaluation_samples
            ],
            rank=config["evaluation_taxlevel"],
        ),
        sort=expand(
            "{root}final_results/{instance_name}.f1.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
    output:
        expand(
            "{root}final_results/{instance_name}.tp.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.tp.json",
            instance_name=config["instance_name"],
            root=root,
        ),
    message:
        "Outputting the tp table..."
    threads: 1
    run:
        dict_for_average = {}
        with open(output[0], "w") as outp:
            outp.write(
                "#LEMMI16_dm:v1.0\ntoolname\tsample\trank\tvalue\n".format(
                    config["Database"]
                )
            )
            for file in input.data:
                toolname = file.split("/")[-1].split(".")[1]
                sample = file.split("/")[-1].split(".")[2]
                rank = file.split("/")[-1].split(".")[3]
                with open(file) as inp:
                    value = inp.read()
                outp.write("{}\t{}\t{}\t{}\n".format(toolname, sample, rank, value))
                # keep the value for average
                try:
                    dict_for_average[toolname][rank].append(value)
                except KeyError:
                    try:
                        dict_for_average[toolname][rank] = [value]
                    except KeyError:
                        dict_for_average[toolname] = {}
                        dict_for_average[toolname][rank] = [value]
            for key_toolname in dict_for_average:
                for key_rank in dict_for_average[key_toolname]:
                    outp.write(
                        "{}\t{}\t{}\t{}\n".format(
                            key_toolname,
                            config["instance_name"],
                            key_rank,
                            np.average(
                                [
                                    float(v)
                                    for v in dict_for_average[key_toolname][key_rank]
                                ]
                            ),
                        )
                    )
        toolbox.to_json(output[0], output[1], config=config, sort_with=input.sort[0])

rule recall_to_final_table:
    input:
        data=expand(
            "{root}evaluations/recall.{toolname}.{evaluation_sample}.{rank}.tsv",
            root=root,
            toolname=toolnames,
            evaluation_sample=[
                "{}-{}".format(config["instance_name"], s) for s in evaluation_samples
            ],
            rank=config["evaluation_taxlevel"],
        ),
        sort=expand(
            "{root}final_results/{instance_name}.f1.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
    output:
        expand(
            "{root}final_results/{instance_name}.recall.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.recall.json",
            instance_name=config["instance_name"],
            root=root,
        ),
    message:
        "Outputting the recall table..."
    threads: 1
    run:
        dict_for_average = {}
        with open(output[0], "w") as outp:
            outp.write(
                "#LEMMI16s_dm:v1.0\ntoolname\tsample\trank\tvalue\n".format(
                    config["Database"]
                )
            )
            for file in input.data:
                toolname = file.split("/")[-1].split(".")[1]
                sample = file.split("/")[-1].split(".")[2]
                rank = file.split("/")[-1].split(".")[3]
                with open(file) as inp:
                    value = inp.read()
                outp.write("{}\t{}\t{}\t{}\n".format(toolname, sample, rank, value))
                # keep the value for average
                try:
                    dict_for_average[toolname][rank].append(value)
                except KeyError:
                    try:
                        dict_for_average[toolname][rank] = [value]
                    except KeyError:
                        dict_for_average[toolname] = {}
                        dict_for_average[toolname][rank] = [value]
            for key_toolname in dict_for_average:
                for key_rank in dict_for_average[key_toolname]:
                    outp.write(
                        "{}\t{}\t{}\t{}\n".format(
                            key_toolname,
                            config["instance_name"],
                            key_rank,
                            np.average(
                                [
                                    float(v)
                                    for v in dict_for_average[key_toolname][key_rank]
                                ]
                            ),
                        )
                    )
        toolbox.to_json(output[0], output[1], config=config, sort_with=input.sort[0])

rule l2_to_final_table:
    input:
        data=expand(
            "{root}evaluations/l2.{toolname}.{evaluation_sample}.{rank}.tsv",
            root=root,
            toolname=toolnames,
            evaluation_sample=[
                "{}-{}".format(config["instance_name"], s) for s in evaluation_samples
            ],
            rank=config["evaluation_taxlevel"],
        ),
        sort=expand(
            "{root}final_results/{instance_name}.f1.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
    output:
        expand(
            "{root}final_results/{instance_name}.l2.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.l2.json",
            instance_name=config["instance_name"],
            root=root,
        ),
    message:
        "Outputting the l2 table..."
    threads: 1
    run:
        sort_tool_by_rank = (
            lambda v: dict_for_ranking[rank][sample][v]
            if dict_for_ranking[rank][sample][v] != -1
            else 1 + max(list(dict_for_ranking[rank][sample].values()))
        )
        with open(output[0], "w") as outp:
            outp.write(
                "#LEMMI16s_dm:v1.0\ntoolname\tsample\trank\tvalue\n".format(
                    config["Database"]
                )
            )
            dict_for_average = {}
            dict_for_ranking = {}
            for file in input.data:
                toolname = file.split("/")[-1].split(".")[1]
                sample = file.split("/")[-1].split(".")[2]
                rank = file.split("/")[-1].split(".")[3]
                with open(file) as inp:
                    value = float(inp.read())
                outp.write("{}\t{}\t{}\t{}\n".format(toolname, sample, rank, value))

                # keep the value for average rank
                try:
                    dict_for_ranking[rank][sample].update({toolname: value})
                except KeyError:
                    try:
                        dict_for_ranking[rank].update({sample: {toolname: value}})
                    except KeyError:
                        dict_for_ranking.update({rank: {sample: {toolname: value}}})
            for rank in dict_for_ranking:
                for sample in dict_for_ranking[rank]:
                    ranking = list(dict_for_ranking[rank][sample].keys())
                    ranking.sort(key=sort_tool_by_rank, reverse=False)
                    for toolname in ranking:
                        try:
                            dict_for_average[toolname][rank].append(
                                ranking.index(toolname) + 1
                            )
                        except KeyError:
                            try:
                                dict_for_average[toolname][rank] = [
                                    ranking.index(toolname) + 1
                                ]
                            except KeyError:
                                dict_for_average[toolname] = {}
                                dict_for_average[toolname][rank] = [
                                    ranking.index(toolname) + 1
                                ]

            for key_toolname in dict_for_average:
                for key_rank in dict_for_average[key_toolname]:
                    outp.write(
                        "{}\t{}\t{}\t{}\n".format(
                            key_toolname,
                            config["instance_name"],
                            key_rank,
                            np.average(
                                [
                                    float(v)
                                    for v in dict_for_average[key_toolname][key_rank]
                                ]
                            ),
                        )
                    )

        toolbox.to_json(output[0], output[1], config=config, sort_with=input.sort[0])

rule memory_analysis_to_final_table:
    input:
        data=expand(
            "{root}analysis_outputs/{toolname}.{evaluation_sample}.memory_analysis.txt",
            root=root,
            toolname=toolnames,
            evaluation_sample=[
                "{}-{}".format(config["instance_name_nosuffix"], s)
                for s in evaluation_samples
            ],
        ),
        sort=expand(
            "{root}final_results/{instance_name}.f1.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
    output:
        expand(
            "{root}final_results/{instance_name}.memory_analysis.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.memory_analysis.json",
            instance_name=config["instance_name"],
            root=root,
        ),
    message:
        "Outputting the memory for analysis table..."
    threads: 1
    run:
        dict_for_average = {}
        with open(output[0], "w") as outp:
            outp.write(
                "#LEMMI16s_dm:v1.0\ntoolname\tsample\tvalue\n".format(
                    config["Database"]
                )
            )
            for file in input.data:
                toolname = file.split("/")[-1].split(".")[0]
                sample = file.split("/")[-1].split(".")[1]
                with open(file) as inp:
                    value = inp.read()
                outp.write("{}\t{}\t{}".format(toolname, sample, value))
                # keep the value for average
                try:
                    dict_for_average[toolname].append(value)
                except KeyError:
                    dict_for_average[toolname] = [value]

            for key_toolname in dict_for_average:
                outp.write(
                    "{}\t{}\t{}\n".format(
                        key_toolname,
                        config["instance_name"],
                        np.average([float(v) for v in dict_for_average[key_toolname]]),
                    )
                )
        toolbox.to_json(output[0], output[1], config=config, sort_with=input.sort[0])

rule runtime_analysis_to_final_table:
    input:
        data=expand(
            "{root}analysis_outputs/{toolname}.{evaluation_sample}.runtime_analysis.txt",
            root=root,
            toolname=toolnames,
            evaluation_sample=[
                "{}-{}".format(config["instance_name_nosuffix"], s)
                for s in evaluation_samples
            ],
        ),
        sort=expand(
            "{root}final_results/{instance_name}.f1.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
    output:
        expand(
            "{root}final_results/{instance_name}.runtime_analysis.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.runtime_analysis.json",
            instance_name=config["instance_name"],
            root=root,
        ),
    message:
        "Outputting the runtime for analysis table..."
    threads: 1
    run:
        dict_for_average = {}
        with open(output[0], "w") as outp:
            outp.write(
                "#LEMMI16s_dm:v1.0\ntoolname\tsample\tvalue\n".format(
                    config["Database"]
                )
            )
            for file in input.data:
                toolname = file.split("/")[-1].split(".")[0]
                sample = file.split("/")[-1].split(".")[1]
                with open(file) as inp:
                    value = inp.read()
                outp.write("{}\t{}\t{}".format(toolname, sample, value))
                # keep the value for average
                try:
                    dict_for_average[toolname].append(value)
                except KeyError:
                    dict_for_average[toolname] = [value]

            for key_toolname in dict_for_average:
                outp.write(
                    "{}\t{}\t{}\n".format(
                        key_toolname,
                        config["instance_name"],
                        np.average([float(v) for v in dict_for_average[key_toolname]]),
                    )
                )
        toolbox.to_json(output[0], output[1], config=config, sort_with=input.sort[0])

rule filtering_thresholds_to_final_table:
    input:
        data=expand(
            "{root}evaluations/filtering_threshold.{toolname}.{instance_name}.{rank}.tsv",
            toolname=toolnames,
            instance_name=config["instance_name"],
            rank=config["evaluation_taxlevel"],
            root=root,
        ),
        sort=expand(
            "{root}final_results/{instance_name}.f1.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
    output:
        expand(
            "{root}final_results/{instance_name}.filtering_threshold.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.filtering_threshold.json",
            instance_name=config["instance_name"],
            root=root,
        ),
    message:
        "Outputting the filtering thresholds table..."
    threads: 1
    run:
        with open(output[0], "w") as outp:
            outp.write(
                "#LEMMI16s_dm:v1.0|{}\ntoolname\trank\tvalue\n".format(
                    config["Database"]
                )
            )
            for file in input.data:
                toolname = file.split("/")[-1].split(".")[1]
                rank = file.split("/")[-1].split(".")[3]
                with open(file) as inp:
                    value = inp.read()
                outp.write("{}\t{}\t{}\n".format(toolname, rank, value))
        toolbox.to_json(
            output[0], output[1], config=config, sort_with=input.sort[0], reverse=True
        )


rule auprc_to_final_table:
    input:
        data=expand(
            "{root}evaluations/auprc.{toolname}.{instance_name}.{rank}.tsv",
            toolname=toolnames,
            instance_name=config["instance_name"],
            rank=config["evaluation_taxlevel"],
            root=root,
        ),
        sort=expand(
            "{root}final_results/{instance_name}.f1.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
    output:
        expand(
            "{root}final_results/{instance_name}.auprc.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.auprc.json",
            instance_name=config["instance_name"],
            root=root,
        ),
    message:
        "Outputting the auprc table..."
    threads: 1
    run:
        with open(output[0], "w") as outp:
            outp.write(
                "#LEMMI16s_dm|{}:v1.0\ntoolname\tsample\trank\tvalue\n".format(
                    config["Database"]
                )
            )
            for file in input.data:
                toolname = file.split("/")[-1].split(".")[1]
                rank = file.split("/")[-1].split(".")[3]
                with open(file) as inp:
                    for line in inp:
                        sample = line.strip().split("\t")[0]
                        value = line.strip().split("\t")[1]
                        outp.write(
                            "{}\t{}\t{}\t{}\n".format(toolname, sample, rank, value)
                        )
        toolbox.to_json(output[0], output[1], config=config, sort_with=input.sort[0])


rule prc_to_final_table:
    input:
        data=expand(
            "{root}evaluations/prc.{toolname}.{instance_name}.{rank}.tsv",
            toolname=toolnames,
            instance_name=config["instance_name"],
            rank=config["evaluation_taxlevel"],
            root=root,
        ),
        sort=expand(
            "{root}final_results/{instance_name}.f1.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
    output:
        expand(
            "{root}final_results/{instance_name}.prc.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.prc.json",
            instance_name=config["instance_name"],
            root=root,
        ),
    message:
        "Outputting the prc table..."
    threads: 1
    run:
        with open(output[0], "w") as outp:
            outp.write(
                "#LEMMI16s_dm:v1.0|{}\ntoolname\trank\tsample\tprecision\trecall\tthreshold\n".format(
                    config["Database"]
                )
            )
            for file in sorted(input.data):
                toolname = file.split("/")[-1].split(".")[1]
                rank = file.split("/")[-1].split(".")[3]
                with open(file) as inp:
                    for line in inp:
                        value = line.strip().split("\t")
                        outp.write(
                            "{}\t{}\t{}\t{}\t{}\t{}\n".format(
                                toolname, rank, value[0], value[1], value[2], value[3]
                            )
                        )
        # do not sort
        toolbox.to_json(output[0], output[1], config=config)

rule memory_training_to_final_table:
    input:
        data=expand(
            "{root}analysis_outputs/{toolname}.{instance_name}.memory_training.txt",
            root=root,
            toolname=toolnames,
             instance_name=config["instance_name"],
        ),
        sort=expand(
            "{root}final_results/{instance_name}.f1.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
    output:
        expand(
            "{root}final_results/{instance_name}.memory_training.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.memory_training.json",
            instance_name=config["instance_name"],
            root=root,
        ),
    message:
        "Outputting the memory for training table..."
    threads: 1
    run:
        with open(output[0], "w") as outp:
            outp.write(
                "#LEMMI16s_dm:v1.0\ntoolname\tsample\tvalue\n".format(
                    config["Database"]
                )
            )
            for file in input.data:
                toolname = file.split("/")[-1].split(".")[0]
                sample = file.split("/")[-1].split(".")[1]
                with open(file) as inp:
                    value = inp.read()
                outp.write("{}\t{}\t{}".format(toolname, sample, value))

        toolbox.to_json(output[0], output[1], config=config, sort_with=input.sort[0])

rule runtime_training_to_final_table:
    input:
        data=expand(
            "{root}analysis_outputs/{toolname}.{instance_name}.runtime_training.txt",
            root=root,
            toolname=toolnames,
            instance_name=config["instance_name"],
        ),
        sort=expand(
            "{root}final_results/{instance_name}.f1.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
    output:
        expand(
            "{root}final_results/{instance_name}.runtime_training.tsv",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.runtime_training.json",
            instance_name=config["instance_name"],
            root=root,
        ),
    message:
        "Outputting the runtime for training table..."
    threads: 1
    run:
        with open(output[0], "w") as outp:
            outp.write(
                "#LEMMI16s_dm:v1.0\ntoolname\tsample\tvalue\n".format(
                    config["Database"]
                )
            )
            for file in input.data:
                toolname = file.split("/")[-1].split(".")[0]
                sample = file.split("/")[-1].split(".")[1]
                with open(file) as inp:
                    value = inp.read()
                outp.write("{}\t{}\t{}".format(toolname, sample, value))
        toolbox.to_json(output[0], output[1], config=config, sort_with=input.sort[0])

rule evaluated_predictions_by_tools_and_ranks:
    input:
        predictions=expand(
            "{root}evaluations/predictions.{{toolname}}.{{instance_name_nosuffix}}-{{all_sample}}.{{rank}}.tsv",
            root=root,
        ),
        truth=expand(
            "{root}instances/{instance_name}/{instance_name}-{{all_sample}}/queryTaxo.tsv",
            root=root,
            instance_name=config["instance_name_nosuffix"],
        ),
        gnc_ref=expand(
            "{root}repository/{Database_name}/GCN_ref.tsv",
            root=root,
            Database_name=Database_name,
        ),
    output:
        expand(
            "{root}final_results/{{toolname}}.{{instance_name_nosuffix}}-{{all_sample}}.{{rank}}.tsv",
            root=root,
        ),
    message:
        "Producing the detailed evaluation of each sample for each tool at each rank"
    threads: 1
    run:
        gcn=toolbox.GCN_reference(input.gnc_ref)
        truth = toolbox.load_truth_reads_predictions(
                gcn,
                input.truth[0],
                wildcards.rank,
                gcn_normalization
            )

        predictions = pd.read_csv(input.predictions[0], header=1, sep="\t")
        predictions = toolbox.evaluation_results(predictions, truth, 0)

        with open(output[0], "w") as outp:
            outp.write(
                "#LEMMI16_dm:v1.0|{}\ntaxa\treads\tabundance\tcorrect_prediction\n".format(
                    config["Database"]
                )
            )
        predictions.to_csv(
            output[0],
            index=False,
            header=False,
            sep="\t",
            mode="a",
        )

rule evaluated_predictions_by_tools_and_ranks_to_json:
    input:
        expand(
            "{root}final_results/{toolname}.{{evaluation_sample}}.{rank}.tsv",
            toolname=toolnames,
            rank=config["evaluation_taxlevel"],
            root=root,
        ),
    output:
        expand(
            "{root}final_results/{{evaluation_sample}}.json",
            root=root,
        ),
    message:
        "Producing the detailed evaluation of each evaluation sample for each tool at each rank in a single json"
    threads: 1
    run:
        col_names = [
            "toolname",
            "rank",
            "taxa",
            "reads",
            "abundance",
            "correct_prediction",
            "appears_in_neg_samples",
        ]
        all_data = pd.DataFrame(columns=col_names)
        for inp in input:
            data = pd.read_csv(inp, sep="\t", header=1)
            try:
                data.loc[:, "toolname"] = inp.split("/")[-1].split(".")[0]
                data.loc[:, "rank"] = inp.split("/")[-1].split(".")[-2]
            except ValueError:
                pass
            all_data = all_data.append(data, ignore_index=True)
            #all_data = pd.concat([all_data, data], ignore_index=True)

        try:
            all_data.sort_values(by=["toolname"], inplace=True)
        except KeyError:
            pass
        all_data.to_json(output[0], index=True, indent=4, orient="index")

rule create_frontend_additional_files:
    output:
        expand(
            "{root}final_results/{instance_name}.structure.json",
            instance_name=config["instance_name"],
            root=root,
        ),
        expand(
            "{root}final_results/{instance_name}.ranks.json",
            instance_name=config["instance_name"],
            root=root,
        ),
    message:
        "Creating default json files for frontend specific content..."
    threads: 1
    run:
        # first to create structure.json (final concatenation made by the lemmi_analysis bash script)
        structure = '\t"{}": {{\n\t\t"{}": [\n\t\t\t"textbox",\n\t\t\t"f1",\n\t\t\t"memory"\n\t\t]\n\t}}'.format(
            config["instance_name"], config["instance_name"]
        )
        with open(output[0], "w") as outp:
            outp.write(structure)
        # the taxonomic ranks
        ranks = '{{\n\t"ranks": {}\n}}'.format(
            ["{}".format(t) for t in config["evaluation_taxlevel"]]
        )
        with open(output[1], "w") as outp:
            outp.write(ranks.replace("'", '"'))

