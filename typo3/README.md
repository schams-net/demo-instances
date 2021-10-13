# TYPO3 Demo Instance

```bash
git clone https://github.com/schams-net/demo-instances
#chmod 744 demo-instances/typo3/bin/deploy.sh
#demo-instances/typo3/bin/deploy.sh
```

```bash
export TF_VAR_profile=default
export TF_VAR_region=eu-central-1
export TF_VAR_volume_size=16

ln -s main.${TF_VAR_region}.tf.tmpl terraform/main.tf

cd terraform
if [ ! -d .terraform ]; then terraform init ; fi
terraform apply -auto-approve

PUBLIC_IPV4=$(echo "module.production.ec2_public_ip" | terraform console | cut -f 2 -d '"')
ssh admin@${PUBLIC_IPV4} "tail -f /var/log/cloud-init-output.log"
```
