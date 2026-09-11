#docker build --rm -t ezlab/mapseq_211_lemmi16s:v1.0_cv1 .
#docker login quay.io -u ezlab
#docker tag ezlab/mapseq_211_lemmi16s:v1.0_cv1 quay.io/ezlab/mapseq_211_lemmi16s:v1.0_cv1

#To build the local image
docker build --rm . -t $USER/mapseq
#docker run --rm -it -v $(pwd):/app $USER/mapseq
