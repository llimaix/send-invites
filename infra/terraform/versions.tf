terraform {
  required_version = "~> 1.17"

  # State local por decisión explícita del proyecto (infra efímera, se destruye
  # después de la fiesta). *.tfstate está en .gitignore. No borrar el state
  # hasta ejecutar el destroy final.

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.73.0"
    }
  }
}
