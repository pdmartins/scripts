# Azure Resource Group Export

## Informações da Exportação

| Campo | Valor |
|-------|-------|
| **Data/Hora** | 2026-01-29 02:55:12 |
| **Tenant ID** | 3c6b75cb-aa67-4b35-b435-d685e2e91240 |
| **Subscription ID** | 5dc87b18-978f-4e64-9449-a258f1f57962 |
| **Resource Group** | AVA_RPA_SKY_RG |

## Recursos Exportados

| Nome | Tipo | Localização |
|------|------|-------------|
| sky-hubai-SP | Microsoft.Web/serverFarms | brazilsouth |
| sky-hubai | Microsoft.Web/sites | brazilsouth |
| sky-hubai-openai | Microsoft.CognitiveServices/accounts | brazilsouth |
| sky-hubai-id | Microsoft.ManagedIdentity/userAssignedIdentities | brazilsouth |
| sky-hubai-hml | Microsoft.Web/sites | brazilsouth |
| oidc-msi-a895 | Microsoft.ManagedIdentity/userAssignedIdentities | brazilsouth |

## Arquivos Gerados

| Arquivo | Descrição |
|---------|-----------|
| `resource_template.json` | Template ARM para importação no novo tenant |
| `resource_template_backup.json` | Backup do template |
| `resource_documentation.md` | Este arquivo de documentação |

## Próximos Passos

1. Execute o script de importação no novo tenant
2. Informe o novo nome do Resource Group
3. Verifique se todos os recursos foram criados corretamente

## Observações

- Alguns sub-recursos (extensions, certificates, siteextensions) não são exportados automaticamente
- Configurações de HTTPS customizado precisam ser reconfiguradas manualmente
- Managed Identities podem precisar de novas permissões no novo tenant
