require(pacman)
p_load(tidyverse,qgraph,igraph,devtools,patchwork,ggrepel,ggiraph,glue,ggnetwork,gtools,colourvalues)
# install_github("nathanhaigh/pcit@v1.6.0")#not on CRAN at the moment (also seems to be broken)

#Import all data
d0<-read_csv("Data/all_populations.csv")
nrow(d0)


# Setup -------------------------------------------------------------------
traits<-c('tail.mean','t.avg.bright','t.hue','t.chrom','r.avg.bright','r.hue','r.chrom','b.avg.bright','b.hue','b.chrom','v.avg.bright','v.hue','v.chrom')
traits_col <- traits[-c(1)]

#limit analysis to pops with at least N samples
(pop_summary<-d0 %>% group_by(population,sex) %>%  summarise(n=n()) %>%  pivot_wider(names_from=sex,values_from=n,names_prefix = "n_") %>% mutate(n_TOT=n_F+n_M) %>% as.data.frame())

#Let's say 20 is our minimium number of each sex
min_samples<-12
pops_w_min_samples<-pop_summary %>% filter(n_F>=min_samples & n_M>=min_samples)
nrow(pops_w_min_samples) #22 populations with at least this many individuals
d<-d0 %>% filter(population %in% pops_w_min_samples$population)
nrow(d)
d$population<-as.factor(d$population)
d$sex<-as.factor(d$sex)


#####################
#####################
# 1. Test `Network Density ~ Mean Darkness` across pops 
# Calculate population-level stats ----------------------------------------
#Male data subset by population
data_list_males<-lapply(levels(d$population),function(x) (subset(d,population==x&sex=="M")))
names(data_list_males)<-levels(d$population)

#Female data subset by population
data_list_females<-lapply(levels(d$population),function(x) (subset(d,population==x&sex=="F")))
names(data_list_females)<-levels(d$population)

#Male correlations by population
corr_list_males<-lapply(names(data_list_males), function(x) cor(as.matrix(data_list_males[[x]][,traits_col]),method="s",use="pairwise.complete"))
names(corr_list_males)<-levels(d$population)

#Female correlations by population
corr_list_females<-lapply(names(data_list_females), function(x) cor(as.matrix(data_list_females[[x]][,traits_col]),method="s",use="pairwise.complete"))
names(corr_list_females)<-levels(d$population)


pop_netdensity_females <- sapply(corr_list_females,function(x) sum(abs(x[upper.tri(x)]))/sum(upper.tri(x)))

pop_netdensity_males <- sapply(corr_list_males,function(x) sum(abs(x[upper.tri(x)]))/sum(upper.tri(x)))

#Make data frame for main figure (with throat and breast chroma and network density)
integ0<-d %>% group_by(population, sex) %>% summarise_at(c("t.chrom","r.chrom"),mean,na.rm=TRUE) %>% arrange(sex,population) %>% rename(mean.t.chrom=t.chrom,mean.r.chrom=r.chrom)
integ0$network_density <- c(pop_netdensity_females,pop_netdensity_males)
integ <- integ0 %>% arrange(sex,desc(network_density))

#throat patch graph
G_t<-ggplot(integ,
       aes(x = mean.t.chrom, y = network_density, fill = mean.t.chrom)) + 
  stat_ellipse() +
  geom_point(size=3,pch=21,col="black") +
  scale_fill_gradient(
    limits = range(integ$mean.t.chrom),
    low = "#FFFFCC",
    high = "#CC6600",
    guide = "none"
  ) + 
  facet_wrap( ~ sex,labeller =as_labeller(c(M="Males",F="Females") )) + 
  ggrepel::geom_label_repel(aes(label =population),col="black",max.overlaps = 20,size=2)+
  xlab("Throat | Average Population Darkness (Chroma)")+
  ylab("Network Density")
#nonsignificant relationship with THROAT darkness & network density for both sexes
cor.test(subset(integ,sex=="F")$mean.t.chrom,
         subset(integ,sex=="F")$network_density,method = "spearman")

cor.test(subset(integ,sex=="M")$mean.t.chrom,
         subset(integ,sex=="M")$network_density,method = "spearman")
                  
                

#breast patch graph
(G_r<-ggplot(integ,
       aes(x = mean.r.chrom, y = network_density, fill = mean.r.chrom)) + 
  stat_ellipse() +
  geom_point(size=3,pch=21,col="black") +
  scale_fill_gradient(
    limits = range(integ$mean.r.chrom),
    low = "#FFFFCC",
    high = "#CC6600",
    guide = "none"
  ) + 
  facet_wrap( ~ sex,labeller =as_labeller(c(M="Males",F="Females") )) + 
  ggrepel::geom_label_repel(aes(label =population),col="black",max.overlaps = 20,size=2)+
  xlab("Breast | Average Population Darkness (Chroma)")+
  ylab("Network Density")
  )

#Significant relationship with BREAST darkness & network density for both sexes
cor.test(subset(integ,sex=="F")$mean.r.chrom,
         subset(integ,sex=="F")$network_density,method = "spearman")

cor.test(subset(integ,sex=="M")$mean.r.chrom,
         subset(integ,sex=="M")$network_density,method = "spearman")



# Output Fig 1.  Darker birds have denser color networks (for R, but not T) --------

#patchwork syntax
(G_combined<-G_t/G_r)
ggsave("figs/Fig 1. network density ~ breast + throat chroma.png",dpi=300)


#Pretty interesting that Egypt has such a low network density for its darkness. 




#make interactive version
G_r_inxn<-ggplot(integ,
       aes(x = mean.r.chrom, y = network_density, fill = mean.r.chrom)) + 
  stat_ellipse() +
  geom_point_interactive(size=3,pch=21,col="black",aes(tooltip=glue("Population: {population}\nBreast Chroma: {round(mean.r.chrom,2)}\nNetwork Density: {round(network_density,2)}"),data_id=population)) +
  scale_fill_gradient(
    limits = range(integ$mean.r.chrom),
    low = "#FFFFCC",
    high = "#CC6600",
    guide = "none"
  ) + facet_wrap(~sex,labeller =as_labeller(c(M="Males",F="Females") ),ncol = 1)+
  ggrepel::geom_label_repel(aes(label =population),col="black",max.overlaps = 20,size=2)+
  xlab("Population Mean Breast Darkness (Chroma)")+
  ylab("Network Density")

htmlwidgets::saveWidget(ggiraph::girafe(ggobj=G_r_inxn),file = "figs/interactive_Fig1_network density~ throat chroma.html",selfcontained = TRUE)


#####################
#####################
# 2. Visualize phenotype networks for sampling of populations

#which populations have > 30 indivs sampled for both M & F?
min_samples_big<-15
pop_summary %>% filter(n_F>=min_samples_big & n_M>=min_samples_big)

#Define populations you want to include in phenonet figures
pops_of_interest<-c("CO","TA","TU","IS","UK","Morocco","Egypt","yekaterinburg","zakaltoose","zhangye")

#Make a handy function to order the vector of populations by network density
order_pops_by_net_density<-function(integ_df,pops,which_sex){
  new_df<-integ_df %>% filter(sex==which_sex,population%in% pops) %>% 
    arrange(network_density)
  new_df$population
}
male_pops<-order_pops_by_net_density(integ,pops_of_interest,"M")
female_pops<-order_pops_by_net_density(integ,pops_of_interest,"F")

#just a check cuz the spelling is all over the place on these names
if(sum(is.na(poi_ordered))>0){warning("Name mismatch. One of your pops_of_interest not matched to 'integ' df.")}


#Define f(x) for subsetting data & getting filtered correlation matrix
get_pop_cormat <- function(pop,which_sex,traits){
   d_cor<- d %>% 
  filter(population==pop & sex==which_sex) %>% 
  select(traits_col) %>% 
   cor(.,use="pairwise.complete",method = "spear")
  d_cor[diag(d_cor)]<-NA
  
  #Filter algorithm
  # Here, simply ≥|0.3|
  d_cor_bad_indx<-which(abs(d_cor)<0.3)
  d_cor[d_cor_bad_indx]<-0
  
  d_cor
}

# output Fig 2 & 3. -----------------------------------------------------------
###Setup
#Get means for traits in each population for each sex
rawmeansM<-d %>% group_by(population) %>% filter(population %in% pops_of_interest,sex=="M") %>% summarise_at(traits_col,mean,na.rm=T)

rawmeansF<-d %>% group_by(population) %>% filter(population %in% pops_of_interest,sex=="F") %>% summarise_at(traits_col,mean,na.rm=T)

# Function Definitions ----------------------------------------------------
####>>>>>>>>>>>>>>>>>>>>>
## Make custom plot function
Q<-function(COR,lab.col,lab.scale,lab.font,lay,...){
  if(missing(lab.col)){lab.col="black"}
  if(missing(lab.scale)){lab.scale=T}
  if(missing(lab.font)){lab.font=2}
  if(missing(lay)){lay="spring"}
  G<-qgraph(COR,diag=F,fade=F,label.color=lab.col,label.font=lab.font,label.scale=lab.scale,label.norm="0000",mar=c(4,7,7,4),...)
return(G)}
#<<<<<<<<<<<<<<<
#

### Generate male networks figure
png("figs/Fig 2. Male_10_Networks_ordered.png",width=13,height=6,units="in",res=300)
par(mfrow=c(2,5),mar=rep(3,4),xpd=T,oma=rep(1,4),ps=18)

#Calculate quantiles for each population's color values to color nodes
  scalar<-sapply(names(rawmeansM)[-1],function(x) as.numeric(gtools::quantcut(unlist(rawmeansM[,x]),q=50 ))) 
  #make 50 quantiles for matching color scores
  rownames(scalar)<-rawmeansM$population
  scalar[,c(1:2,4:5,7:8,10:11)] <-51- scalar[,c(1:2,4:5,7:8,10:11)]  #reverse brightness & hue measures so lower values are darker
  #define color ramp with 50 gradations
  nodepal<-colorRampPalette(c("#FFFFCC","#CC6600"),interpolate="spline")(50) 

for (i in 1: length(male_pops)){
  cur_pop<-male_pops[i]
  mat<-get_pop_cormat(cur_pop,"M",traits_col)
  nodecolor<-nodepal[scalar[as.character(cur_pop),]]
 # groupings<-list(throat=1:3,breast=4:6,belly=7:9,vent=10:12)
  Q(mat,color=nodecolor,border.color="gray20",labels=toi3,shape=shps,posCol="#181923",negCol=1,vsize=20,lab.col="#181923",lab.font=2,lab.scale=F,label.cex=.7,label.scale.equal=T,layout="circle",rescale=TRUE)
  
  mtext(cur_pop,3,line=.6,at=-1.4,adj=0,col="#181923",cex=.6,font=2)

    #Add bounding rectangle for Egypt
  if(cur_pop=="Egypt"){
    box(which="figure",lwd=3)
    #rect(xleft = -1.6,ybottom = -1.25,xright = 1.25,ytop = 1.6,border="cyan",lwd=3)
  }
  

  
}
dev.off()

################
### Generate female networks figure
png("figs/Fig 3. Female_10_Networks_ordered.png",width=13,height=6,units="in",res=300)
par(mfrow=c(2,5),mar=rep(3,4),xpd=T,oma=rep(1,4),ps=18)

#Calculate quantiles for each population's color values to color nodes
  scalar<-sapply(names(rawmeansF)[-1],function(x) as.numeric(gtools::quantcut(unlist(rawmeansF[,x]),q=50 ))) 
  #make 50 quantiles for matching color scores
  rownames(scalar)<-rawmeansF$population
  scalar[,c(1:2,4:5,7:8,10:11)] <-51- scalar[,c(1:2,4:5,7:8,10:11)]  #reverse brightness & hue measures so lower values are darker
  #define color ramp with 50 gradations
  nodepal<-colorRampPalette(c("#FFFFCC","#CC6600"),interpolate="spline")(50) 

for (i in 1: length(female_pops)){
  cur_pop<-female_pops[i]
  print(i)
  mat<-get_pop_cormat(cur_pop,"F",traits_col)
  nodecolor<-nodepal[scalar[as.character(cur_pop),]]

  Q(mat,color=nodecolor,border.color="gray20",labels=toi3,shape=shps,posCol="#181923",negCol=1,vsize=20,lab.col="#181923",lab.font=2,lab.scale=F,label.cex=.7,label.scale.equal=T,lay="circle",rescale=TRUE)
  
  mtext(cur_pop,3,line=.6,at=-1.4,adj=0,col="#181923",cex=.6,font=2)

    #Add bounding rectangle for Egypt
  if(cur_pop=="Egypt"){
    box(which="figure",lwd=3)
    #rect(xleft = -1.6,ybottom = -1.25,xright = 1.25,ytop = 1.6,border="cyan",lwd=3)
  }
  

  
}
dev.off()


###DS: Implementing calculation of INT coefficient for phenotypic integration

data_list_males
traits_col

lapply(data_list_males function(x){
  data_list_males[[x]][,traits_col]})
