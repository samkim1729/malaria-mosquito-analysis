# ----------------------------------------- #
#        Spat21 Data Set Importing          #
#              Mosquito Data                #
#            December 18, 2018              #
#            K. Sumner, S. Kim              #
# ----------------------------------------- #

#### ------------------ load packages ------------------ ####
library(readr)
library(dplyr)
library(tidyr)
library(lubridate)
library(magrittr)


#### ---------------- set up environment --------------- ####
.wd <- "~/Projects/Malaria collab/Spatial R21 projects/Spat21 cleaning, analysis/"
ALLSPECIES_FP <- paste0(.wd, "Data/Mosquito Data Sets/MOZZIECollectionSummary_June2017_July2018.csv")
ANOPHELES_FP  <- paste0(.wd, "Data/Mosquito Data Sets/MOZZIEFemaleAnophele_June2017_July2018.csv")
QPCR_FP       <- paste0(.wd, "Data/Mosquito Data Sets/Mozzie mosquito compiled detection results 18Dec2018.csv")
DATA_DICT_FP  <- paste0(.wd, "Data/Data Dictionary/spat21_data_mosquito_dictionary.csv")
IMPORTED_FP   <- paste0(.wd, "Data/Mosquito Data Sets/moz_imported_data.Rdata")
LOG_FP        <- paste0(.wd, "Code/spat21_moz_data_import.log")
close(file(LOG_FP, open="w"))  # clear log file
write.log <- function(...) {
  for(output in list(...)) {
    write(output, file=LOG_FP, append=TRUE)
  }
  write("", file=LOG_FP, append=TRUE)
}
.zero <- 1e-6  # threshold for zero CT value


#### ------------- read in mosquito data --------------- ####

write.log("# ------ IMPORT RAW DATA ------ #")

# Read in the mosquito descriptive data sets.
# Read in the data set with all mosquito species.
allspecies_data    <- read.csv(ALLSPECIES_FP, stringsAsFactors=FALSE)
# Read in the wide data set with only anopheles mosquitoes.
anopheles_widedata <- read.csv(ANOPHELES_FP, stringsAsFactors=FALSE)
# Read in the mosquito qPCR data sets.
qpcr_data          <- read.csv(QPCR_FP, stringsAsFactors=FALSE)

# Clean column names.
names(anopheles_widedata) %<>%
  { tolower(gsub("..",  ".", ., fixed=TRUE)) } %>%
  { tolower(gsub("\\.$", "", .)) }  # remove trailing periods
anopheles_widedata %<>% rename(form.entered.date = form.entered.on)  # consistent name

# Look at summaries of all the data sets.
summary(allspecies_data)
summary(anopheles_widedata)
summary(qpcr_data)
str(allspecies_data)
str(anopheles_widedata)
str(qpcr_data)
write.log("allspecies_data dims:",    paste(ncol(allspecies_data), "vars"), paste(nrow(allspecies_data), "obs"))
write.log("anopheles_widedata dims:", paste(ncol(anopheles_widedata), "vars (10 + 16*6 + 5)"),
                                      paste(nrow(anopheles_widedata), "obs (or more)"))
write.log("qpcr_data dims:",          paste(ncol(qpcr_data), "vars"),       paste(nrow(qpcr_data), "obs"))

# Output a CSV file of all the variable names.
allnames <- data.frame(c(names(allspecies_data), names(anopheles_widedata), names(qpcr_data)))
write_csv(allnames, DATA_DICT_FP)


#### ------ reformat all species descriptive data ------ ####

write.log("# ------ REFORMAT ALL SPP. DESCRIPTIVE DATA ------ #")

# Rename and reformat columns.
names(allspecies_data) <- c("household.id","repeat.instrument","repeat.instance","collection.date","collection.time","village","collection.done.by",
                            "anoph.unfed","anoph.bloodfed","anoph.halfgravid","anoph.gravid","anoph.undetermined","anoph.total","num.male.anoph",
                            "culex.unfed","culex.bloodfed","culex.halfgravid","culex.gravid","culex.undetermined","culex.total","num.male.culex",
                            "form.checked.by","form.checked.date","form.entered.by","form.entered.date","complete")
allspecies_data %<>%
  mutate_at(c("household.id","repeat.instrument","village","collection.done.by","form.checked.by","form.entered.by","complete"), factor) %>%
  mutate_at(c("repeat.instance",
              "anoph.unfed","anoph.bloodfed","anoph.halfgravid","anoph.gravid","anoph.undetermined","anoph.total","num.male.anoph",
              "culex.unfed","culex.bloodfed","culex.halfgravid","culex.gravid","culex.undetermined","culex.total","num.male.culex"), as.integer) %>%
  mutate_at(c("collection.date","form.checked.date","form.entered.date"), mdy) %>%
  mutate_at(c("collection.time"), as.logical)
write.log("Renamed columns")


#### ------------ reformat descriptive data ------------ ####

write.log("# ------ REFORMAT ANOPH. DESCRIPTIVE DATA ------ #")

# Reformat columns from wide to long.
anopheles_data <- as.data.frame(matrix(nrow=16*nrow(anopheles_widedata), ncol=21), stringsAsFactors=FALSE)  # long data, overshooting # of rows
names(anopheles_data) <- c("household.id","repeat.instrument","repeat.instance","collection.date","collection.time","village",
                           "collection.done.by","samples.prepared.by","species.id.done.by","total.number.of.mosquitos.in.the.household",
                           "sample.id.head","sample.id.abdomen","abdominal.status","species.type","specify.species","comment",
                           "form.checked.by","form.checked.date","form.entered.by","form.entered.date","complete")
.count <- 1
for(.i in 1:nrow(anopheles_widedata)) {
  .header <- anopheles_widedata[.i, 1:10]
  .footer <- anopheles_widedata[.i, 107:111]
  for(.j in 1:16) {
    if(anopheles_widedata[[.i, 5+6*.j]] != "") {  # first column of j-th "block"
      anopheles_data[.count, ] <- c(.header, anopheles_widedata[.i, (5+6*.j):(10+6*.j)], .footer)
      .count <- .count + 1
    }
  }
}
anopheles_data %<>% filter(!is.na(household.id))  # trim empty rows
anopheles_data[anopheles_data==""] <- NA

# Rename and reformat columns.
anopheles_data %<>%
  mutate_at(c("household.id","repeat.instrument","village","collection.done.by","samples.prepared.by","species.id.done.by",
              "abdominal.status","species.type","specify.species","form.checked.by","form.entered.by","complete"), factor) %>%
  mutate_at(c("repeat.instance","total.number.of.mosquitos.in.the.household"), as.integer) %>%
  mutate_at(c("collection.date","form.checked.date","form.entered.date"), mdy) %>%
  mutate_at(c("collection.time"), as.logical)
write.log("Reformatted data from wide to long")
write.log("anopheles_data dims:", paste(ncol(anopheles_data), "vars"), paste(nrow(anopheles_data), "obs"))

# Standardize sample ID format.
anopheles_data %<>%
  mutate_at(c("sample.id.head","sample.id.abdomen"), function(x) { gsub("\\s*A\\s*", " A", x) }) %>%
  mutate_at(c("sample.id.head","sample.id.abdomen"), function(x) { gsub("\\s*H\\s*", " H", x) })
write.log("Standardized sample ID spacing")


#### ---------------- reformat qPCR data --------------- ####

write.log("# ------ REFORMAT QPCR DATA ------ #")

# Rename and reformat columns.
names(qpcr_data)[11] <- "pfr364R^2"
qpcr_data[qpcr_data == "Undetermined"] <- NA
qpcr_data %<>%
  mutate_at(c("Sample.Name","Experiment.Name"), factor) %>%
  mutate_at(c("HbtubCT1","HbtubCT2","pfr364CT1","pfr364CT2","pfr364Std5a","pfr364Std5b","pfr364Std6a","pfr364Std6b"), as.numeric)
qpcr_data[is.na(qpcr_data)] <- NA  # correct NaNs to NAs

# Standardize sample ID format.
qpcr_data %<>%
  mutate(Sample.Name=gsub("\\s?A\\s?", " A", Sample.Name)) %>%
  mutate(Sample.Name=gsub("\\s?H\\s?", " H", Sample.Name))
write.log("Standardized sample ID spacing")

# Process qPCR Ct values.
qpcr_data$Has.Hb <- FALSE
qpcr_data$Has.Pf <- FALSE
qpcr_data$Has.Hb[which(qpcr_data$HbtubCT1<.zero & qpcr_data$HbtubCT2<.zero & qpcr_data$pfr364CT1<.zero & qpcr_data$pfr364CT2<.zero)] <- NA
qpcr_data$Has.Pf[which(is.na(qpcr_data$Has.Hb))] <- NA
write.log("Zero Ct is defined as Ct<0.000001")
qpcr_data %<>%
  mutate_at(c("HbtubCT1","HbtubCT2","pfr364CT1","pfr364CT2","pfr364Q1","pfr364Q2"), function(x) { ifelse(x<.zero, NA, x) })
qpcr_data$Has.Hb[which(qpcr_data$HbtubCT1>=.zero  | qpcr_data$HbtubCT2>=.zero)]  <- TRUE
qpcr_data$Has.Pf[which(qpcr_data$pfr364CT1>=.zero | qpcr_data$pfr364CT2>=.zero)] <- TRUE
write.log("All zero Ct's marked as missing",
          "Any positive Ct marked as positive",
          "Everything else marked as negative")
qpcr_data %<>% .[c(names(.)[1:5], "Has.Hb", names(.)[6:9], "Has.Pf", names(.)[10:24])]

# Tabulate qPCR Ct counts.
qpcr_counts <- rbind(table(qpcr_data$Has.Hb, useNA="always"), table(qpcr_data$Has.Pf, useNA="always"))
rownames(qpcr_counts) <- c("Hb","Pf")
colnames(qpcr_counts) <- c("Neg","Pos","Missing")
qpcr_counts[["Pf","Pos"]] %<>% { . - 1 }  # no parasitemia for M06 A00026
qpcr_counts[["Pf","Neg"]] %<>% { . + 1 }  # no parasitemia for M06 A00026
write.table(qpcr_counts, col.names=NA, file=LOG_FP, append=TRUE, quote=FALSE, sep="\t")
write.log()
write.log("No parasitemia for M06 A00026, considered missing")


#### ------------ export reformatted data -------------- ####
save(allspecies_data, anopheles_data, qpcr_data, file=IMPORTED_FP)