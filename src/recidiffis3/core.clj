(ns recidiffis3.core
  (:require [cognitect.aws.client.api :as aws]
            [cheshire.core :as json]
            [clojure.java.io :as io]
            [recidiffist.diff :as diff]
            [taoensso.timbre :as log]
            [unsiemly.core :as uc]
            [unsiemly.internal :as ui]
            [unsiemly.env :as ue])
  (:gen-class
   :implements [com.amazonaws.services.lambda.runtime.RequestStreamHandler]))

(defn ^:private get-version-data
  "Given an S3 object, its bucket, and an etag, return an iterable of S3 version
  data with this version and previous versions.

  This would be more efficient if it took a version id and not an etag, but the
  Lambda event we're working from doesn't have a version id in it. The etag at
  least allows us to identify _which_ write we're seeing.

  (TODO) We assume that writes aren't so delayed that ListObjectVersions will
  return the thing we need on the first page.

  (TODO: validate) we assume that S3 returns versions newest first, which
  appears to be the case in every example and would make sense but also isn't
  spelled out anywhere in the documentation.
  "
  [s3 bucket key etag]
  (eduction
   (filter (comp #{key} :Key))
   (drop-while (comp #{etag} :Etag))
   (-> s3
       (aws/invoke
        {:op :ListObjectVersions
         :request {:Bucket bucket :Prefix key}})
       log/spy
       :Versions)))

(defn ^:private get-specific-version
  "Get a specific version of an object from an S3 bucket."
  [s3 bucket key version-id]
  (aws/invoke s3 {:op :GetObject :request {:Bucket bucket :Key key :VersionId version-id}}))

(defn ^:private parse-json
  "Convert the given object to a java.io.PushbackReader and parse as JSON."
  [maybe-reader]
  (json/parse-stream (io/reader maybe-reader) keyword))

(defn -handleRequest
  "Given a Lambda S3 event, finds all object puts in the event and sends diffs off
  somewhere."
  [this in-stream out-stream context]
  (let [results (for [{s3-event :s3 region :awsRegion} (-> in-stream parse-json :Records)
                      :when s3-event
                      :let [{:keys [bucket object]} s3-event
                            bucket (bucket :name)
                            {key :key new-etag :eTag} object
                            s3 (aws/client {:api :s3 :region region})
                            [curr-v prev-v] (->> (get-version-data s3 bucket key new-etag)
                                                 (take 2))
                            [curr prev] (eduction
                                         (map (comp (partial get-specific-version s3 bucket key)
                                                 :VersionId))
                                         (map (comp parse-json :Body))
                                         (log/spy [curr-v prev-v]))
                            version-details #(select-keys % [:LastModified :VersionId :ETag])]]
                  (log/spy
                   (array-map ;; preserve order
                    :bucket bucket
                    :key key
                    :prev (version-details prev-v)
                    :curr (version-details curr-v)
                    :diff (diff/fancy-diff prev curr))))]
    (log/info "writing to unsiemly")
    ((ui/entries-callback (log/spy (ue/opts-from-env!))) results)
    (flush)))
