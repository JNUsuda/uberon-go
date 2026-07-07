# uberon-go v2.0 ---------------------------------------------------------------
# https://github.com/JNUsuda/uberon-go
# July 2026

# install/load packages
#BiocManager::install("rols")
#BiocManager::install('Homo.sapiens')
{library("rols")
library("dplyr")
library("tidyr")
library("stringr")
library("GOfuncR")
library("yaml")}

#set path to save tables ("./" for current working directory)
my_path = "./data/"

# input desired ontology and term id 
term = olsTerm("uberon", "UBERON:0002405")


# get term id and label for file names
termid = termId(term)
termid = gsub(termid, pattern = ":", replacement = "_")
termid # check ID
termname = termLabel(term)
termname = gsub(termname, pattern = "[^[:alpha:]]", replacement = "-")
termname # check term name


# create folder to save files (!!!)
# if there is a folder with the same name, will not overwrite
dirnm = paste0(termname, "_", termid)
dirnm
if (!(dirnm %in% list.dirs(my_path))) {
  dir.create(path = paste0(my_path, dirnm))
}

## 1. descendant anatomical terms ----------------------------------------------

# get relative terms
propr = rols::olsProperties(term)

# get list of descendants
indexes = grep(names(propr@x), pattern = "Descendant")
lista = propr@x[indexes]
lista = append(term,lista) # add searched term as first item

# df of descendants
descs2 = lapply(lista, function(x){
  sublist = list()
  sublist[["id"]]  = x@obo_id
  sublist[["label"]]  =  x@label
  sublist[["subset"]]  =  paste(unlist(x@in_subset), collapse = ";")
  return(sublist)})
descs_df = do.call(rbind.data.frame, descs2) %>% distinct()


# save table (careful with overwrites!!!)
desc_name = paste0(my_path, dirnm, "/", dirnm, "_descendants.txt")
desc_name
write.table(descs_df, file = desc_name, 
            sep = "\t", col.names = T, row.names = F)

#### optionally, filter human subsets ------------------------------------------
# filter for human subsets

# for both human_reference_atlas and human_subset:
descs_df2 = descs_df %>% filter(str_detect(subset, pattern = "human")) 
#descs_df2 = descs_df %>% filter(str_detect(subset, pattern = "human_reference_atlas"))
#descs_df2 = descs_df %>% filter(str_detect(subset, pattern = "human_subset"))

# get list of descendants filtered to human
indexes2 = which(names(lista) %in% rownames(descs_df2))
lista2 = lista[indexes2]
lista2 = append(term,lista2) # adds searched term as first item

# save table (careful with overwrites!!!)
desc_name2 = paste0(my_path, dirnm, "/", dirnm, "_descendants_human.txt")
desc_name2
write.table(descs_df2, file = desc_name2,
            sep = "\t", col.names = T, row.names = F)


## 2. related GO terms ------------------------------------------------------------

# list of GO terms
# (!!!) WARNING: may take long to complete (!!!)
# It may encounter timeout errors. 
# Simply continue running the "while" loop, WITHOUT restarting i to 1, until complete (i=length(lista)+1)

GO_rels = list()
i=1
while (i<=length(lista)) {
  x = lista[[i]]
  link = x@links$graph$href
  rels = rjson::fromJSON(file = paste(link))
  rels2 = do.call(rbind.data.frame, rels$edges)
  labs = do.call(rbind.data.frame, rels$nodes)
  GO_rels0 = rels2 %>% 
    mutate(source_label = recode_values(source, from = labs$iri, to = labs$label)) %>% 
    relocate(source_label, .after = source) %>% 
    mutate(target_label = recode_values(target, from = labs$iri, to = labs$label)) %>%  
    relocate(target_label, .after = target) %>%
    dplyr::rename(rel = uri, rel_label = label) %>% 
    relocate(rel, .after = source_label) %>% 
    relocate(rel_label, .after = rel) %>% 
    filter(str_detect(source, pattern = "http://purl.obolibrary.org/obo/GO_")|
             str_detect(target, pattern = "http://purl.obolibrary.org/obo/GO_"))
  GO_rels[[i]] = GO_rels0
  i=i+1
}


# df of GO terms
GO_rels_df = do.call(rbind.data.frame, GO_rels) %>% 
  distinct() %>%   
  tibble::remove_rownames()

GO_terms = GO_rels_df %>% 
  mutate(across(c(source, target), str_extract, pattern = "GO_[[:digit:]]+", 
                .names = "{.col}_extract")) %>% 
  mutate(go_id = coalesce(source_extract, target_extract),
         .keep = "unused") %>% 
  mutate(go_id = gsub(go_id, pattern = "_", replacement = ":"))

GO_terms_df = GOfuncR::get_names(GO_terms$go_id)


GO_rels_df2 = GO_terms %>% 
  mutate(source = gsub(source, 
                       pattern = "http://purl.obolibrary.org/obo/", 
                       replacement = ""),
         source = gsub(source, pattern = "_", replacement = ":")) %>% 
  mutate(rel = gsub(rel, 
                    pattern = "http://purl.obolibrary.org/obo/", 
                    replacement = ""),
         rel = gsub(rel, pattern = "_", replacement = ":")) %>% 
  mutate(target = gsub(target, 
                       pattern = "http://purl.obolibrary.org/obo/", 
                       replacement = ""),
         target = gsub(target, pattern = "_", replacement = ":")) %>% 
  distinct()

# save relationship table (careful with overwrites!!!)
rels_name = paste0(my_path, dirnm, "/", dirnm, "_GO-relations.txt")
rels_name
write.table(GO_rels_df2, file = rels_name,
            sep = "\t", col.names = T, row.names = F)

# optional: evaluate relationships to filter in next section

## 3. related GO BPs -----------------------------------------------------------

# subset BPs and get descendants from BPs
BPs = GO_terms_df %>% 
  filter(root_node == "biological_process") 
GO_d_terms_df = GOfuncR::get_child_nodes(BPs$go_id) %>% 
  distinct(.keep_all = T)
GO_d_terms_df2 = right_join(BPs, GO_d_terms_df, relationship = "many-to-many",
                            by = join_by(go_id == parent_go_id)) %>% 
  select(-c(root_node)) %>% 
  distinct(.keep_all = T)
colnames(GO_d_terms_df2) = c("parent_id", "parent_label", 
                             "descendant_id", "descendant_label", "distance")

# save BPs table (careful with overwrites!!!)
BP_name = paste0(my_path, dirnm, "/", dirnm, "_GO-BPs.txt")
BP_name
write.table(GO_d_terms_df2, file = BP_name, 
            sep = "\t", col.names = T, row.names = F)

# to read existing table:
#GO_d_terms_df2 = read.table(file = BP_name, sep = "\t", header = T)

#### optionally, filter out BPs ------------------------------------------------
### EDIT ACCORDINGLY TO YOUR CASE!!!!

labels_to_remove = c() # labels of parent BPs to filter, e.g. "blood circulation"
ids_to_remove = c() # ids of parent BPs to filter, e.g. "GO:0001755"
child_to_remove = c() # ids of child BPs to filter (and their descendants; other children/descendants from the parent term will be kept), e.g. "GO:0001755"
child_to_remove0 = GOfuncR::get_child_nodes(child_to_remove) 
child_to_remove = c(child_to_remove0$child_name)

GO_d_terms_df3 = GO_d_terms_df2 %>% 
  filter(!(parent_label %in% labels_to_remove) & 
           #!(parent_id %in% ids_to_remove) & 
           !(descendant_label %in% child_to_remove)
         ) 

# save BPs table (careful with overwrites!!!)
BP_name2 = paste0(my_path, dirnm, "/", dirnm, "_GO-BPs_filtered.txt")
BP_name2
write.table(GO_d_terms_df3, file = BP_name2, 
            sep = "\t", col.names = T, row.names = F)

# save filter parameters (careful with overwrites!!!)
filtros = list(removed_labels = labels_to_remove, 
                     removed_ids = ids_to_remove,
                     removed_children_of = child_to_remove)
BPpar_name = paste0(my_path, dirnm, "/", dirnm, "_GO-BPs_filter_param.txt")
BPpar_name
yaml::write_yaml(filtros, file = BPpar_name)

# to read existing file:
#filtros = read_yaml(file = BPpar_name)

## 4. related genes ------------------------------------------------------------

# 4.1: genes functionally related to term (RECOMMENDED)
# 4.2: genes annotated in GO as related to anatomical terms 

### 4.1. genes annotated to selected BPs ---------------------------------------

# genes related to the GO BPs:

my_go_fun = function(go) {
  tryCatch({
    GOfuncR::get_anno_genes(go) %>%
      tidyr::pivot_wider(
        names_from = go_id,
        values_from = gene
      ) %>%
      t()
  }, error = function(e) NULL)
}

# get list of unique genes
u_genes_fun = function(lista) { 
  u_genes = unlist(lista[[1]])
  i = 2
  while (i<= length(lista)) {
    genes3 = unlist(lista[[i]])
    if (any(!(genes3 %in% u_genes))) {
      genes4 = which(!(genes3 %in% u_genes))
      u_genes = c(u_genes, genes3[genes4])
    }
    i=i+1
  }
  return(u_genes)
}

# for all BPs:
list1 <- lapply(unique(BPs$go_id), my_go_fun)
names(list1) <- unique(BPs$go_id)
unique_genes1 = u_genes_fun(list1)

# save relationship table (careful with overwrites!!!)
genes_name = paste0(my_path, dirnm, "/", dirnm, "_genes.txt")
genes_name
write.table(unique_genes1, file = genes_name, quote = F,
            sep = "\t", col.names = F, row.names = F)

#### optionally, for filtered BPs ----------------------------------------------

list2 = lapply(unique(GO_d_terms_df3$descendant_id), my_go_fun)
names(list2) <- unique(GO_d_terms_df3$descendant_id)
unique_genes2 = u_genes_fun(list2)

# save relationship table (careful with overwrites!!!)
genes_name2 = paste0(my_path, dirnm, "/", dirnm, "_genes_filtered.txt")
genes_name2
write.table(unique_genes2, file = genes_name2, quote = F,
            sep = "\t", col.names = F, row.names = F)


### 4.2. genes annotated to selected anatomical terms --------------------------

# download desired GOA from GO:
# https://www.geneontology.org/docs/download-go-annotations/

# load go annotations - human
goa_human <- readr::read_delim("./goa_human_release-2024-11-03.gaf", 
                               delim = "\t", escape_double = FALSE, 
                               col_names = FALSE, comment = "!", trim_ws = TRUE,
                               show_col_types = FALSE)
colnames(goa_human) = c("DB","DB_ID", "DB_Symbol","Relation","GO_ID",
                        "DB_Reference","Evidence_Code","With_From","Aspect",
                        "DB_Name","DB_Synonym","DB_Type","Taxon","Date",
                        "Assigned_By","Annotation_Extension",
                        "Gene_Product_Form_ID")

# string of anatomy terms for searching:
labels3 = paste(descs_df$id, collapse = "|")
# search form anatomy terms in the Annotation_Extension column
related_genes = goa_human %>% 
  filter(str_detect(Annotation_Extension, pattern = labels3)) %>% 
  distinct(DB_Symbol)

# save table (careful with overwrites!!!)
genes_path = paste0(my_path, dirnm, "/", dirnm, "_genes.txt")
genes_path
write.table(related_genes, file = genes_path, 
            sep = "\t", col.names = F, row.names = F)

