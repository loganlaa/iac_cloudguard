# ==============================================================================
# Module: Diagram as Code — Outputs
# ==============================================================================

output "mermaid_file" {
  description = "Caminho do arquivo Mermaid (.mmd) gerado"
  value       = local_file.topology_mermaid.filename
}

output "markdown_file" {
  description = "Caminho do arquivo Markdown (.md) com diagrama Mermaid embutido"
  value       = local_file.topology_markdown.filename
}

output "python_diagrams_file" {
  description = "Caminho do script Python (Mingrammer diagrams) gerado"
  value       = local_file.topology_python_diagrams.filename
}

output "png_file" {
  description = "Caminho do PNG gerado (quando render_png = true)"
  value       = var.render_png ? "${var.output_dir}/aws_topology.png" : null
}
