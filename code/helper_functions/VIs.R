# add more VIs
moreVIs <- function(df){ 
  df %>% 
    mutate(
      NDVI = (nir-red)/(nir+red),
      NDWI = (green-nir)/(green+nir),
      mNDWI1 = (green-swir1)/(green+swir1),
      mNDWI2 = (green-swir2)/(green+swir2),
      NDMI1 = (nir-swir1)/(nir+swir1),
      NDMI2 = (nir-swir2)/(nir+swir2),
      NDRE = (nir-red_edge_1)/(nir+red_edge_1),
      NDPI = (swir1-green)/(swir1+green),
      BU3 = red + swir1 - nir,
      AWEI = (green-swir2) - (0.25*nir + 2.75*swir1),
      AWEISH = blue + 2.5*green - 1.5*(nir+swir1) - 0.25*swir2,
      BSI = ((swir1+red-nir-blue)/(swir1+red+nir+blue))*100 + 100,
      DVW = NDVI-NDWI,
      DVI = nir-red,
      IFW = nir-green,
      IPVI = nir/(nir+red),
      MBSRV = green+red,
      MBSRN = nir+swir1,
      MIFW = swir1-green,
      OSAVI = (nir-red)/(nir+red+0.16),
      SAVI = ((nir-red)/(nir+red+0.5))*1.5,
      RVI = nir/red,
      TVI = 0.5*(120*(nir-green)-200*(red-green)),
      WRI = (green+red)/(nir+swir1),
      WTI = 0.91*red + 0.43*nir,
      VARI = (green-red)/(green+red-blue),
      BGR = blue/green,
      GRR = green/red,
      RBR = red/blue,
      SRBI = blue-red,
      NPCRI = (red-blue)/(red+blue), # Normalized Pigment Chlorophyll Ratio Index 
      EVI3b = 2.5 * (nir - red)/(nir + (6*red) - (7.5*blue) + 1),
      EVI2b = 2.5 * (nir - red)/ (nir + (2.4*red) + 1),
      ABWI = (blue+green+red-(nir+swir1+swir2))/(blue+green+red+nir+swir1+swir2),
      TCB = (0.3510*blue) + (0.3813*green) + (0.3437*red) + (0.7196*nir) + (0.2396*swir1) + (0.1949*swir2), 
      TCG = (-0.3599*blue) - (0.3533*green) - (0.4734*red) + (0.6633*nir) + (0.0087*swir1) - (0.2856*swir2), 
      TCW = (0.2578*blue) + (0.2305*green) + (0.0883*red) + (0.1071*nir) - (0.7611*swir1) - (0.5308*swir2), 
      
        )
}