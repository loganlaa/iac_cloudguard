# Módulo `diagram_as_code`

Módulo opcional de **Diagram as Code** para gerar automaticamente a topologia gráfica AWS a partir das variáveis, CIDRs e feature flags definidos no código Terraform.

## O que este módulo gera

Quando habilitado (`enable_diagram = true` no root), o módulo cria no diretório `output_dir` (padrão `docs/`):

1. `topology.md`: Documento Markdown com o diagrama **Mermaid** embutido + tabela resumo dos laboratórios ativos (renderiza nativamente no GitHub, GitLab e VS Code sem dependências externas).
2. `topology.mmd`: Código-fonte puro do diagrama Mermaid.
3. `topology_aws_icons.py`: Script Python compatível com a biblioteca [`diagrams`](https://diagrams.mingrammer.com/) (ícones oficiais da AWS) para geração de PNG de alta resolução.

## Uso Opcional

Por padrão, `enable_diagram = false`, portanto o módulo **não** é executado e não altera nenhum recurso ou fluxo existente.

Para gerar apenas o diagrama sem provisionar recursos na AWS:

```bash
terraform apply -target=module.diagram_as_code -var="enable_diagram=true"
```

Para gerar também a imagem PNG automaticamente durante o `apply` (requer `pip install diagrams` e `graphviz` instalados localmente):

```bash
terraform apply -target=module.diagram_as_code -var="enable_diagram=true" -var="diagram_render_png=true"
```
