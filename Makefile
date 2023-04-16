init:
	ssh-keygen -q -f keys/key -N ''
    terraform init

validate:
    terraform fmt -recursive
    terraform validate

plan:
    terraform validate
    terraform plan -var-file="variables.tfvars"

apply:
    terraform apply --auto-approve

destroy:
    terraform destroy

all: validate plan apply