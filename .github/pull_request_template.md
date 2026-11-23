## Cambio
<!-- Qué cambia y por qué. Enlaza el CHG o el incidente si aplica. -->

## Riesgo
<!-- Bajo / medio / alto. Qué servidores o servicios afecta y si hay corte de servicio. -->

## Pruebas realizadas
- [ ] `scripts/ci-local.sh` en verde
- [ ] `ansible-playbook site.yml --check --diff` revisado (si toca Ansible)
- [ ] `terraform plan` revisado (si toca Terraform)
- [ ] Otras:

## Plan de reversión
<!-- Cómo se deshace: git revert + ansible-playbook, terraform apply del commit anterior, snapshot... -->
