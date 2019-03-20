(defproject recidiffist-s3 "0.1.0-SNAPSHOT"
  :description "Structural diffs for S3 versioned objects"
  :url "https://github.com/latacora/recidiffist-s3"
  :license {:name "EPL-2.0"
            :url "https://www.eclipse.org/legal/epl-2.0/"}
  :dependencies [[org.clojure/clojure "1.10.0"]
                 [recidiffist "0.11.0"]
                 [com.amazonaws/aws-lambda-java-core "1.2.0"]
                 [com.cognitect.aws/api "0.8.273"]
                 [com.cognitect.aws/endpoints "1.1.11.507"]
                 [com.cognitect.aws/s3 "697.2.391.0"]
                 [cheshire "5.8.1"]
                 [com.latacora/unsiemly "0.10.0"]
                 [com.taoensso/timbre "4.10.0"]]
  :main ^:skip-aot recidiffist-s3.core
  :target-path "target/%s"
  :jar-name "recidiffist-s3.jar"
  :uberjar-name "recidiffist-s3-standalone.jar"
  :profiles {:uberjar {:aot :all}})
