#!/usr/bin/env bash
# Remove ONE golden-path service's AWS resources after a demo (ECS service, ALB rule,
# target group, IAM roles, log group, ECR images + repository).
#
# Usage: deploy/scripts/teardown-service.sh <service-name>
#
# Safety: asks you to retype the service name; never touches the shared platform
# (VPC, ALB, cluster) or any other service. The GitHub repository and the catalog
# entry are NOT deleted by this script (see the instructions it prints at the end).
set -euo pipefail
NAME="${1:?usage: $0 <service-name>}"
OWNER="0019-KDU"
REGION="ap-south-1"
REPO_NAME="devops94-idp-svc-${NAME}"

[[ "$NAME" =~ ^[a-z][a-z0-9-]{1,20}[a-z0-9]$ ]] || { echo "invalid service name"; exit 1; }
[[ "$NAME" == "reference-api" ]] && { echo "refusing: reference-api is the permanent demo reference service"; exit 1; }

echo "This destroys the AWS resources of service '${NAME}' (dev) in ${REGION}."
read -r -p "Type the service name to confirm: " CONFIRM
[[ "$CONFIRM" == "$NAME" ]] || { echo "aborted"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
git clone --quiet --depth 1 "https://github.com/${OWNER}/${NAME}.git" "$WORK/repo"
cd "$WORK/repo/infra"
terraform init -input=false >/dev/null

# ECR refuses to delete a repository that still contains images
IMAGES="$(aws ecr list-images --region "$REGION" --repository-name "$REPO_NAME" --query 'imageIds[*]' --output json 2>/dev/null || echo '[]')"
if [[ "$IMAGES" != "[]" ]]; then
  echo "Deleting images from ${REPO_NAME}"
  aws ecr batch-delete-image --region "$REGION" --repository-name "$REPO_NAME" --image-ids "$IMAGES" >/dev/null
fi

# image_tag is a required variable of the service stack; its value is irrelevant for destroy
terraform destroy -input=false -auto-approve -var "image_tag=teardown"

cat <<EOF

AWS resources for '${NAME}' removed. Finish manually:
  1. Backstage: open the '${NAME}' component → ⋮ → "Unregister entity".
  2. GitHub:    https://github.com/${OWNER}/${NAME}/settings → Danger Zone → Delete (or Archive).
  3. Optional:  the Terraform state file s3://devops94-idp-tfstate-697502032879/services/${NAME}/ is
                now empty; it can be kept (versioned) or deleted.
EOF
