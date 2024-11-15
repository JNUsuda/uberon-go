# uberon-go

Welcome to uberon-go, where the anatomy ontology (UBERON)[http://uberon.org/] meets Gene Ontology (GO) to programatically download their relations.

An R script is provided to obtain, relative to an anatomy ontology term:
- descendant anatomic terms;
- related Gene Ontology (GO) Biological Process (BP) terms;
- related genes.

Sample results for some UBERON terms (nervous system UBERON:0001016; immune system, UBERON:0002405) are in the results folder.

## Descendant terms

Children and further descendants from an anatomic ontology term are obtained from the Ontology Lookup Service ([OLS](https://www.ebi.ac.uk/ols4/)) through the R package rols.  
These generally include anatomic terms (UBERON), cell terms from cell ontology (CL), and cellular component terms (GO CC).  
The parent term is included for familiar completeness.  
For large families (hundreds of descendants), it may take several minutes to complete the OLS queries.  

Example:
(head da tabela)

## Related GO BPs

For each term of the obtained descendants, the related GO terms are obtained from the Ontology Lookup Service ([OLS](https://www.ebi.ac.uk/ols4/)) through the R package rols.  
The term names, root node (BP/CC), and descendants of the obtained terms are retrieved with the R package GOfuncR.  
For large families (hundreds of descendants), it may take several minutes to complete the OLS queries.  

Example:
(head da tabela)


## Genes

For each term of the obtained descendants, the related genes are obtained from the GO annotations for _Homo sapiens_, available at [http://current.geneontology.org/products/pages/downloads.html](http://current.geneontology.org/products/pages/downloads.html). Annotations for other organisms can also be used.

Example:
(head da tabela)
