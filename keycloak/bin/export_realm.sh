pod=$(kubectl get pods | grep sense-kc-0 | awk '{print $1}')
kubectl exec -it $pod -- bash
#
# From here, need manual intervention.

# Find the java run command and copy it.
ps aux | grep java

# Add the following flag: -Djgroups.bind.port=7900
# Replace the command string with: export --dir /tmp/export --bootstrap-admin-password=testpass -realm StackV

# Should look similar to the following:
# /opt/bitnami/java/bin/java -Dkc.config.built=true -Djava.util.concurrent.ForkJoinPool.common.threadFactory=io.quarkus.bootstrap.forkjoin.QuarkusForkJoinWorkerThreadFactory -XX:MetaspaceSize=96M -XX:MaxMetaspaceSize=256m -Dfile.encoding=UTF-8 -Dsun.stdout.encoding=UTF-8 -Dsun.err.encoding=UTF-8 -Dstdout.encoding=UTF-8 -Dstderr.encoding=UTF-8 -XX:+ExitOnOutOfMemoryError -Djava.security.egd=file:/dev/urandom -XX:+UseG1GC -XX:FlightRecorderOptions=stackdepth=512 -XX:MaxRAMPercentage=70 -XX:MinRAMPercentage=70 -XX:InitialRAMPercentage=50 --add-opens=java.base/java.util=ALL-UNNAMED --add-opens=java.base/java.util.concurrent=ALL-UNNAMED --add-opens=java.base/java.security=ALL-UNNAMED -Duser.language=en -Duser.country=US -Djgroups.dns.query=new-keycloak-sense-kc-headless.sense.svc.cluster.local -Dkc.home.dir=/opt/bitnami/keycloak/bin/.. -Djboss.server.config.dir=/opt/bitnami/keycloak/bin/../conf -Djava.util.logging.manager=org.jboss.logmanager.LogManager -Dpicocli.disable.closures=true -Dquarkus-log-max-startup-records=10000 -Djgroups.bind.port=7900 -cp /opt/bitnami/keycloak/bin/../lib/quarkus-run.jar io.quarkus.bootstrap.runner.QuarkusEntryPoint -cf /opt/bitnami/keycloak/conf/keycloak.conf export --dir /tmp/export --bootstrap-admin-password=testpass -realm StackV

# Exit and copy the files from the /tmp/export directory.
