# Install spinnaker in GKE using terraform and helm

### Prerequisite 

* Runs only on Linux or Mac
* Following tools needs to be installed in local machine and available via `PATH` 
    * [gcloud SDK](https://cloud.google.com/sdk/install)
    * [kubectl](https://cloud.google.com/kubernetes-engine/docs/quickstart) (`gcloud components install kubectl`)
    * [terraform](https://www.terraform.io/intro/getting-started/install.html)
    
### Variables
* `credential`: Contents of a file that contains terraform service account private key in JSON format.
   Default filename is account.json. Refer below installation steps to generate key file
* `project`: The ID of the GCP project
* `zone`: [Compute engine zone](https://cloud.google.com/compute/docs/regions-zones/) where GKE cluster needs to be created 
* `gcs_location`: Cloud storage [bucket location](https://cloud.google.com/storage/docs/bucket-locations) for storing spinnaker data
    > By default [Nearline](https://cloud.google.com/storage/docs/storage-classes#nearline) storage class is configured. 
    Ensure correct location is configured based on the configured `zone` 


## Installation steps

1.  `terraform` uses [Service Usage API](https://github.com/terraform-providers/terraform-provider-google/blob/master/CHANGELOG.md#1130-may-24-2018),
    this API needs to be enabled manually
    https://console.developers.google.com/apis/library/serviceusage.googleapis.com

2.  Create service account for `terraform` 
    ```
    gcloud iam service-accounts create terraform --display-name "terraform"
    gcloud iam service-accounts keys create account.json --iam-account terraform@$(gcloud info --format='value(config.project)').iam.gserviceaccount.com
    ```
    Above command will download the key and store it in `account.json` file
    
3.  Grant owner role to terraform service account    
    ```
    gcloud projects add-iam-policy-binding $(gcloud info --format='value(config.project)') --member serviceAccount:terraform@$(gcloud info --format='value(config.project)').iam.gserviceaccount.com --role roles/owner
    ```
    
4.  Execute below commands. This will take some time to complete (5 to 8 mins)
    ```
    terraform init
    terraform plan -out terraform.plan
    terraform apply terraform.plan 
    ```
    
5.  After the command completes, run the following command to set up port forwarding to the Spinnaker UI 
    ```
    export KUBECONFIG=$PWD/.kubeconfig 
    export DECK_POD=$(kubectl get pods --namespace default -l "component=deck" -o jsonpath="{.items[0].metadata.name}")
    kubectl port-forward --namespace default $DECK_POD 8080:9000 >> /dev/null &
    ```
    
6.  Access spinnaker UI at http://localhost:8080/ 

## Setting up attestor

As the API is subject to change, if issues arise reference [the official article][binauthz-attestors]

**NB: much of this will ideally be done via Terraform once the Binauth+CA providers are up to scratch**

1. Set note ID variable (this is whatever your parent authority) and human readable description
    ```shell
    export NOTE_ID="test-attestor-note"
    export NOTE_DESCRIPTION="Test Attestor Note"
    export PAYLOAD_PATH="/tmp"
    export PAYLOAD_FILE="${PAYLOAD_PATH}/ca_note_payload.json"
    ```
1. Create Container Analysis (grafeas) payload
    ```shell
    cat > ${PAYLOAD_FILE} <<EOM
    {
        "name": "projects/${PROJECT_ID}/notes/${NOTE_ID}",
        "attestation_authority": {
            "hint": {
                "human_readable_name": "${NOTE_DESCRIPTION}"
            }
        }
    }
    EOM
    ```
1. Create the note
    ```shell
    curl --request POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $(gcloud auth print-access-token)" \
        --data-binary @${PAYLOAD_FILE} \
        "https://containeranalysis.googleapis.com/v1beta1/projects/${PROJECT_ID}/notes/?noteId=${NOTE_ID}"
    ```
1. Verify note was created
    ```shell
    curl \
        -H "Authorization: Bearer $(gcloud auth print-access-token)" `
        "https://containeranalysis.googleapis.com/v1beta1/projects/${PROJECT_ID}/notes/"
    ```
1. Create IAM payload 
    ```shell
    cat > "${PAYLOAD_PATH}/iam_request.json" <<EOM
    {
        "resource": "projects/${PROJECT_ID}/notes/${NOTE_ID}",
        "policy": {
            "bindings": [
                {
                    "role": "roles/containeranalysis.notes.occurrences.viewer",
                    "members": [
                        "serviceAccount:${ATTESTOR_SERVICE_ACCOUNT}"
                    ]
                }
            ]
        }
    }
    EOM
    ```
1. Add the service account + requested roles
    ```shell
    curl -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $(gcloud auth print-access-token)" \
        --data-binary @/tmp/iam_request.json \
        "https://containeranalysis.googleapis.com/v1alpha1/projects/${PROJECT_ID}/notes/${NOTE_ID}:setIamPolicy"

### Generation of key pairs

The [official article][binauthz-attestors] shows generation via gpg, however we're using Vault - full instructions are in the 






<!-- 


References and links 


-->

[binauthz-attestors]: https://cloud.google.com/binary-authorization/docs/creating-attestors
[vault-on-gke]: https://github.com/gcp-spikers/vault-on-gke-no-project
