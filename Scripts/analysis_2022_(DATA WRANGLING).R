require(pacman)
p_load(tidyverse,skimr)


# Import all data files ---------------------------------------------------
# original 8pop data
# CO=Colorado, CZ=Czech Rep., IS=Israel, NY=New York, RO=Romania, TA=Taiwan, TU=Turkey, UK
pops_8<-read_csv("Data/8pop.MF.TCS.csv") %>% 
        mutate(population=recode(Pop,Colorado="CO")) #some vals are Colorado; should be CO
#just make all the names lowercase as a first step to merging.
names(pops_8)<-tolower(names(pops_8))
#change _ to . for conformity with other pops
names(pops_8) <- gsub("_","\\.",names(pops_8))

#Asian pops (Russia, China, Mongolia, Japan)
pops_asia<-read_csv("Data/all individual phenotype data/asia_pheno_all.csv")
names(pops_asia)<-tolower(names(pops_asia))

#Morocco
pops_mor<-read_csv("Data/all individual phenotype data/morocco_pheno_all.csv")
names(pops_mor)<-tolower(names(pops_mor))

#Egypt
pops_egy<-read_csv("Data/all individual phenotype data/egypt_pheno_all.csv")
names(pops_egy)<-tolower(names(pops_egy))


# Define traits of interest -----------------------------------------------
# And ensure all pops have same names

toi<-c('band','population','year','sex','ci1','rs','tail.mean','weight','date','t.avg.bright','t.hue','t.chrom','r.avg.bright','r.hue','r.chrom','b.avg.bright','b.hue','b.chrom','v.avg.bright','v.hue','v.chrom')


# Define function for checking names of datasets --------------------------


toi_names_match<-function(df){
  df_names<-names(df)
  sapply(1:length(toi),function(i){
    matched <- toi[i]%in%df_names
    ifelse(!matched,"MISSING","---")
  })
}

#What names are missing/mismatched?
data.frame(TOI=toi,
       not_in_pop8=toi_names_match(df=pops_8),
       not_in_asia=toi_names_match(df=pops_asia),
       not_in_mor=toi_names_match(df=pops_mor),
       not_in_egypt=toi_names_match(df=pops_egy)
       )


# Fix missing variables across all data sets ------------------------------
pops_8 <-
  pops_8 %>% 
   rename(
    weight = mass,
    t.avg.bright = t.avg.brightness,
    b.avg.bright = b.avg.brightness,
    r.avg.bright = r.avg.brightness,
    v.avg.bright = v.avg.brightness) %>% 
  mutate(tail.mean = mean(c(mlts, mrts), na.rm = TRUE)) #add tail.mean
pops_asia <-
  pops_asia %>%
  mutate(
    population= pop3, #I believe this is the most relevant column
    date = NA,
    year = NA,
    ci1 = NA,
    rs = NA
  )
pops_mor <- 
  pops_mor %>% 
  rename() %>% 
  mutate(
    population= "Morocco",
    year= "2016",
    ci1 = NA,
    rs = NA
  )

pops_egy <- 
  pops_egy %>% 
  rename() %>% 
  mutate(
    population= "Egypt",
    year= "2015",
    ci1 = NA,
    rs = NA
  )

#Are all names matching now?
#What names are missing/mismatched?
data.frame(TOI=toi,
       not_in_pop8=toi_names_match(df=pops_8),
       not_in_asia=toi_names_match(df=pops_asia),
       not_in_mor=toi_names_match(df=pops_mor),
       not_in_egypt=toi_names_match(df=pops_egy)
       )
#YES


# Remove outliers in each pop ---------------------------------------------
#####
## Define function to change Outliers to NA

NA_outliers <- function(df, QUANTILE_RANGE,id=NA,ignore) {
  # df should be a dataframe or matrix; QUANTILE_RANGE should be in the form c(.01,.99);
  # optional id (e.g. "band" or "bandyear") should be column name for reporting which values were switched to NA
  # ignore (not required) should be a vector a la c("length","width") or c(1:9), which specifies columns to ignore;
  # factors are ignored automatically, but you may wish to ignore some numeric columns as well

  if(missing(QUANTILE_RANGE)){QUANTILE_RANGE<-c(0.01,0.99)} #default quantile range

  df.orig<-df #for adding ignored columns back in at the end
  if(!missing(ignore)){
    if(is.numeric(ignore)){df<-df[,-ignore]
      ignames<-names(df.orig)[ignore]
      }else{df<-df[,-match(ignore,names(df))]
      ignames<-ignore}
      IGNORED<-df.orig[,ignames]} #make subset of data frame with selected columns removed, accounting for how columns are specified (numeric or names)

  #For checking data organization
check_class<-function(dataframe){
  #Check that columns are appropriately assigned to factor, numeric, etc
  Class<- sapply(1:length(dataframe),function(x)class(dataframe[,x]))
  ColumnName<-names(dataframe)
  return(cbind(ColumnName,Class))
}


  #Define function for calculating outliers and replacing with NA for vectors (each column)
  vector.outlier.remover<-function(x,QUANTILE_RANGE,na.rm=T,...)
  {
    if(is.numeric(x)) #only runs script on numeric columns
    {
      qnt <- quantile(x, probs=QUANTILE_RANGE, na.rm = na.rm)
      H <- 1.5 * IQR(x, na.rm = na.rm)
      y <- x
      y[x < (qnt[1] - H)] <- NA
      y[x > (qnt[2] + H)] <- NA
      return(y)
    }else{return(as.character(x))}
  }#end vector.outlier.remover

  OUTPUT<-apply(df,2,function(x) {vector.outlier.remover(x,QUANTILE_RANGE)} )

  #Get indices for reporting changes
  CHANGED.index<-which(is.na(OUTPUT)&!is.na(df),arr.ind=T)
  ###MAke factors in OUTPUT match factors of columns in df
  class.df<-check_class(as.data.frame(df))[,"Class"]
  OUTPUT<-data.frame(OUTPUT,stringsAsFactors = F)
  for(i in 1: length(df))
  {
    if(class.df[i]=="factor"){OUTPUT[,i]<-as.factor(as.character(OUTPUT[,i]))
    }else{class(OUTPUT[,i])<-class.df[i]}
  }
  #Combine with ignored columns, make sure names stay same
  if(!missing(ignore)){
    OUTPUT<-cbind(data.frame(OUTPUT,stringsAsFactors = F),IGNORED)
    }else{OUTPUT<-OUTPUT}



  if(attributes(CHANGED.index)$dim[1]==0){
    return(list(newdata=OUTPUT,changelog="No Changes"))
  }else{
    CHANGED<-t(sapply(1:length(CHANGED.index[,1]),function(x) {
      id_x<-ifelse(is.na(id),
                   paste0("row ", CHANGED.index[x, "row"]),
                   as.character(OUTPUT[CHANGED.index[x, "row"], id]))
      data.frame(ID=id_x,
        COLUMN=names(df)[CHANGED.index[x, "col"]],
        OUTLIER=unlist(signif(df[CHANGED.index[x, "row"], CHANGED.index[x, "col"]], 3)),
        MEAN=signif(mean(unlist(df[, CHANGED.index[x, "col"]]), na.rm = T), 3))
    }
    ))
    CHANGED<-data.frame(CHANGED,stringsAsFactors = F)
    return(list(newdata=OUTPUT,changelog=CHANGED))
  }

}#End NA_outliers


#Check for outliers (nondestructive; changelog=="No Changes" means no crazy values)
#pops_8
NA_outliers(pops_8[,toi],id = "band",ignore=c("date","year","ci1","rs", "population","sex"))
#pops_8 Seems Good, but there's apparently a lot of indivs with messed up chroma values in the 100s
(tmp <- pops_8 %>% filter(t.chrom>1|b.chrom>1|r.chrom>1|v.chrom>1))
#26 screwed up chrom rows, , so we'll just take em out since we have tons of CO indivs
pops_8 <-  pops_8 %>% filter(!(t.chrom>1|b.chrom>1|r.chrom>1|v.chrom>1))
#test again...should be empty tibble
 pops_8 %>% filter(t.chrom>1|b.chrom>1|r.chrom>1|v.chrom>1)
#OK, fixed.

#pops_asia
NA_outliers(pops_asia[,toi],id = "band",ignore=c("date","year","ci1","rs", "population","sex"))
#pops_asia Good

#pops_mor
NA_outliers(pops_mor[,toi],id = "band",ignore=c("date","year","ci1","rs", "population","sex"))
# Some crazy weights in the Moroccan data. Let's NA them
pops_mor<-NA_outliers(pops_mor[,toi],id = "band",ignore=c("date","year","ci1","rs", "population","sex"))$newdata %>% as_tibble()
#test that it worked
NA_outliers(pops_mor[,toi],id = "band")
#pops_mor good


#pops_egy
NA_outliers(pops_egy[,toi],id = "band",ignore=c("date","year","ci1","rs", "population","sex"))
#pops_egy Good

#Everything looks good!


# Combine data ------------------------------------------------------------
pops_egy$band <- as.character(pops_egy$band)
pops_mor$band <- as.character(pops_mor$band)
pops_8$year <- as.character(pops_8$year)
pops_8$date<-as.character(pops_8$date)
allpops<-bind_rows(pops_8[,toi],pops_asia[,toi],pops_mor[,toi],pops_egy[,toi])

#76 Populations!!!
allpops$population %>% unique() %>% length()


# #Remove uncertain individuals -------------------------------------------
#Remove individuals with ? for sex
allpops$sex %>% unique()
allpops$sex<-toupper(allpops$sex)
allpops_certain_sexes<-allpops %>% filter(sex %in% c("M","F"))
nrow(allpops)-nrow(allpops_certain_sexes) #how many indivs removed for indeterminate sex

# Remove duplicate individuals --------------------------------------------
#Make sure to only take 1 individualXpop
allpops_summ0<-allpops_certain_sexes %>% group_by(population) %>%  summarise(n=n()) %>% as.data.frame()
nrow(allpops_certain_sexes)
allpops_certain_sexes$band_x_pop<-paste(allpops_certain_sexes$band,allpops_certain_sexes$population)
allpops_final<-allpops_certain_sexes %>% filter(!duplicated(band_x_pop))
allpops_summ<-allpops_final %>% group_by(population) %>%  summarise(n=n()) %>% as.data.frame()
#Changes (sample size before and after removing duplicates over years)
data.frame(population=allpops_summ0$population,before=allpops_summ0$n,after=allpops_summ$n,change=allpops_summ$n-allpops_summ0$n)
#~600 indivs removed from NY, CO, and TR
nrow(allpops_final) 



# Output combined data ----------------------------------------------------

write_csv(allpops_final,"Data/all_populations.csv")

