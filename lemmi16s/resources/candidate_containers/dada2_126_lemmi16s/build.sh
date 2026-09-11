#To push a container image to quay.io
#docker build --rm -t ezlab/dada2_126_lemmi16s:v1.0_cv1 .
#docker login quay.io -u ezlab
#docker tag ezlab/dada2_126_lemmi16s:v1.0_cv1 quay.io/ezlab/dada2_126_lemmi16s:v1.0_cv1

#To build the local image
docker build --rm . -t $USER/dada2
#docker run --rm -it -v $(pwd):/app $USER/dada2
