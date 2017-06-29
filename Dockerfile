FROM risingstack/alpine:3.4-v6.10.3-4.5.0

WORKDIR /usr/src/stress-test
RUN npm install -g artillery
ADD ./stress.sh .
ADD ./payload.csv .
ADD ./app8-socket-stress.yaml .

VOLUME /artillery
WORKDIR /artillery
# Ports used by the app
EXPOSE 3000

ENTRYPOINT ["/usr/src/stress-test/stress.sh"]
