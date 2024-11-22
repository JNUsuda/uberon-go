# uberon ----

# install/load packages
#BiocManager::install("rols")
library("rols")
library("dplyr")
library("stringr")
library("GOfuncR")

#set path to save tables ("./" for current working directory)
my_path = "./"

# input desired ontology and term id 
term = Term("uberon", "UBERON:0002405")

## descendant anatomical terms ------

# get term id and label for file names
termid = termId(term)
termid = gsub(termid, pattern = ":", replacement = "_")
termid
termname = termLabel(term)
termname = gsub(termname, pattern = "[^[:alpha:]]", replacement = "-")
termname

# get relative terms
propr = Properties(term)

# get list of descendants
indexes = grep(names(propr@x), pattern = "Descendant")
lista = propr@x[indexes]
lista = append(term,lista) # add searched term as first item

# df of descendants
descs2 = lapply(lista, function(x){
  sublist = list()
  #sublist[["label"]] 
  sublist[["label"]]  =  x@label
  sublist[["id"]]  = x@obo_id
  return(sublist)})
descs_df = do.call(rbind.data.frame, descs2)

# save table (careful with overwrites!!!)
desc_name = paste0(my_path, termname, "_", termid, "_descendants.txt")
desc_name
write.table(descs_df, file = desc_name, 
            sep = "\t", col.names = T, row.names = F)

## related BPs -----------------------------------------------------------------

# list of GO terms
GO_rels = lapply(lista, function(x){
  link = x@links$graph$href
  rels = rjson::fromJSON(file = paste(link))
  rels = do.call(rbind.data.frame, rels$edges)
  GO_rels = rels %>% 
    filter(str_detect(source, pattern = "http://purl.obolibrary.org/obo/GO_")|
           str_detect(target, pattern = "http://purl.obolibrary.org/obo/GO_"))
  return(GO_rels)
})

# df of GO terms
GO_rels_df = do.call(rbind.data.frame, GO_rels) %>% distinct()
table(GO_rels_df$label)
GO_terms = c(GO_rels_df[,"source"], GO_rels_df[,"target"]) %>% unique()
GO_terms_idx = GO_terms %>% grep(pattern = "http://purl.obolibrary.org/obo/GO_") 
GO_terms = GO_terms[GO_terms_idx] %>% 
  gsub(pattern = "http://purl.obolibrary.org/obo/", replacement = "") %>% 
  gsub(pattern = "_", replacement = ":")
GO_terms_df = GOfuncR::get_names(GO_terms)

# subset BPs and get descendants from BPs
BPs = GO_terms_df %>% 
  filter(root_node == "biological_process") 
GO_d_terms_df = GOfuncR::get_child_nodes(BPs$go_id) %>% 
  distinct(child_go_id, .keep_all = T) %>% 
  dplyr::select(child_go_id, child_name) 
colnames(GO_d_terms_df) = c("id", "label")


# save BPs table (careful with overwrites!!!)
BP_name = paste0(my_path ,termname, "_", termid, "_GO-BPs.txt")
BP_name
write.table(GO_d_terms_df, file = BP_name, 
            sep = "\t", col.names = T, row.names = F)


### optionally, evaluate relationships to filter terms: ------------------------

# labels table
BPs2 = BPs[,1:2] %>% relocate(go_name, .before = go_id)
colnames(BPs2) = colnames(descs_df)
labels_tab = rbind(descs_df,BPs2)

GO_rels_df2 = GO_rels_df[,1:3] %>% 
  rename(relation = label) %>% 
  mutate(source = gsub(source, 
                   pattern = "http://purl.obolibrary.org/obo/", 
                   replacement = ""),
         source = gsub(source, pattern = "_", replacement = ":")) %>% 
  inner_join(labels_tab, by = join_by(source == id)) %>% 
  rename(source_name = label) %>% 
  mutate(target = gsub(target, 
                       pattern = "http://purl.obolibrary.org/obo/", 
                       replacement = ""),
         target = gsub(target, pattern = "_", replacement = ":")) %>% 
  inner_join(labels_tab, by = join_by(target == id)) %>% 
  rename(target_name = label) %>% 
  relocate(source_name, .after = source) %>% 
  relocate(target_name, .after = target) %>% 
  relocate(relation, .before = target)

# save relationship table (careful with overwrites!!!)
rels_name = paste0(my_path, termname, "_", termid, "_GO-relations.txt")
rels_name
write.table(GO_rels_df2, file = rels_name,
sep = "\t", col.names = T, row.names = F)

## related genes ---------------------------------------------------------------

# download desired GOA from GO:
# https://www.geneontology.org/docs/download-go-annotations/

# load go annotations - human
goa_human <- readr::read_delim("./goa_human.gaf", 
                         delim = "\t", escape_double = FALSE, 
                         col_names = FALSE, comment = "!", trim_ws = TRUE)
colnames(goa_human) = c("DB","DB_ID", "DB_Symbol","Relation","GO_ID",
                        "DB_Reference","Evidence_Code","With_From","Aspect",
                        "DB_Name","DB_Synonym","DB_Type","Taxon","Date",
                        "Assigned_By","Annotation_Extension",
                        "Gene_Product_Form_ID")

# string of anatomy terms for searching:
labels3 = paste(descs_df$obo_id, collapse = "|")
# search form anatomy terms in the Annotation_Extension column
related_genes = goa_human %>% 
  filter(str_detect(Annotation_Extension, pattern = labels3)) %>% 
  distinct(DB_Symbol)

# save table (careful with overwrites!!!)
genes_path = paste0(my_path ,termname, "_", termid, "_genes.txt")
genes_path
write.table(related_genes, file = genes_path, 
            sep = "\t", col.names = T, row.names = F)

