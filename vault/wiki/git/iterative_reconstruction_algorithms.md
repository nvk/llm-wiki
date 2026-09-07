---
title: "Iterative Reconstruction Algorithms"
concept_id: "iterative_reconstruction_algorithms"
domain: "git"
source: "Grainger & Allison / Core / Crack the Core (Lossless Concept Index)"
status: "verified_source"---

# Iterative Reconstruction Algorithms

**System:** GIT  
**Multi-Book Sources:** Grainger & Allison's Diagnostic Radiology | Core Radiology | Crack the Core Exam Review  

## 1. Grainger & Allison's Diagnostic Radiology (Pages 16-17)

### Key Visuals & Figures (Grainger)
![Iterative Reconstruction Algorithms Figure](assets/grainger_iterative_reconstruc_p17_img1.jpeg)

![Iterative Reconstruction Algorithms Figure](assets/grainger_iterative_reconstruc_p17_img2.jpeg)

![Iterative Reconstruction Algorithms Figure](assets/grainger_iterative_reconstruc_p17_img3.jpeg)

478
SECTION B  Abdominal Imaging
becoming increasingly conscious of the exposure to ionising radiation 
associated with CT. This concern results partially from recent coverage 
in the scientific literature and media, which highlights the potential for 
increased cancer risk to patients as a result of increasing use of CT.
Carcinogenesis is the primary concern and it is a proven stochastic 
effect of exposure to ionising radiation. A stochastic effect occurs 
randomly and no lower threshold of ionising radiation exposure exists 
where cancer induction does not occur. Carcinogenesis usually occurs 
many years remote from the exposure and is, therefore, of particular 
concern in patients who are young and in those with chronic disease 
who are subjected to repeated CT examinations over the course of their 
illness. Young cohorts at particular risk for high cumulative effective 
dose include those with curable malignancies such as testicular cancer 
and Hodgkin’s lymphoma, those with inflammatory bowel disease, 
particularly Crohn’s disease, cystic fibrosis patients and patients who 
repeatedly present with renal colic.
Currently, there is a considerable research and industry drive to 
reduce radiation exposure during CT while preserving image quality 
and diagnostic yield. One of the first technological steps towards CT 
dose reduction was to reduce inefficiencies of radiation delivery. Fixed-
tube kilovoltage and amperage settings were commonly used in older-
generation CT systems. Using these fixed-tube settings for CT of the 
abdomen and pelvis resulted in wider areas such as the mid-abdomen 
receiving the same exposure as narrower regions such as the pelvis, 
frequently with no improvement in image quality. This inefficient method 
of dose delivery was the target of one of the most successful and now 
widely implemented dose-reduction technologies: namely, automatic 
exposure control or automatic tube current modulation (ATCM).
AUTOMATIC TUBE CURRENT MODULATION
Automatic tube current modulation tailors the output of the CT tube 
to the patient’s size and shape based on the patient’s diameter and the 
x-ray attenuation of the tissues through which the radiation beam is 
passing. This automated process ensures that thicker regions of the 
body are imaged using higher tube currents than thinner, less attenuating 
areas. Initial trials examining the utility of ATCM found that image 
quality could be preserved while radiation exposure was significantly 
reduced. Early clinical trials demonstrated that dose reductions could 
be achieved in almost 90% of examinations and that the tube–current 
time product was reduced by an average of 32% while using ATCM. 
Further reductions in CT dose, beyond the elimination of inefficiencies 
in dose delivery, are inherently associated with an increase in image 
noise. Noise is defined as the statistical variation in attenuation values 
of CT images, which does not reflect anatomy and blurs image contrast. 
Increased image noise is particularly problematic when imaging patho-
logical changes with a low lesion–background contrast. Accuracy in 
detecting small focal lesions of the liver, spleen and kidneys may be 
negatively influenced by even a slight increase in image noise, whereas 
when imaging the bowel or the renal tract (for potential urinary calculi), 
a higher amount of image noise is usually acceptable because of the 
higher lesion–background contrast.
In patient groups with Crohn’s disease and with urinary calculi and 
also in patients with suspected appendicitis, clinical trials demonstrate 
preservation of diagnostic accuracy despite significant reductions in 
radiation dose and consequential increases in image noise.
Emerging CT noise-reduction strategies have provided new strategies 
for reducing CT dose while maintaining image quality. These methods 
are already showing great promise in abdominopelvic CT and the 
widespread dissemination of technologies such as iterative reconstruction 
is likely to result in CT dose reductions on the order of 75% and greater 
in future years.
ITERATIVE RECONSTRUCTION ALGORITHMS
Iterative image reconstruction (IR) algorithms were used to generate 
images for the first commercial clinical CT systems but the limited 
processing abilities of computers in the early days of CT forced manu-
facturers to use a more computationally efficient method of IR known 
as filtered back projection (FBP). The greater image noise associated 
with low-dose CT imaging is poorly handled by FBP alone and the use 
of IR has recently been revisited as a more appropriate method for 
low-dose imaging reconstruction. Modern computers with improved 
computational capability and speeds have allowed iterative IR to enter 
the clinical domain and iterative IR techniques currently represent the 
most exciting dose-optimising developments in CT. Multiple generations 
of IR are being developed and tested by CT manufacturers. IR algorithms 
may operate on the image data or, preferably, on the raw projection 
data from the CT system itself. Some IR algorithms operate on a 
combination of FBP and IR and are referred to as hybrid algorithms. 
IR images were initially described as being ‘waxy’, ‘plastic’ or ‘over-
smoothened’ in appearance in the case of early algorithms but later 
generations of IR have yielded more acceptable images, which are mildly 
‘mottled’ or ‘pixelated’. With time, radiologists have also become 
accustomed to images reconstructed with IR and are more accepting 
of these characteristics. Expert opinion in this area suggests that imagers 
tend to adapt to the new quality of these images in a relatively short 
period of time.
Hybrid IR algorithms are typically noise efficient, computationally 
fast and studies have indicated that images have good low-contrast detail 
and preserved image quality even with radiation dose reductions of at 
least 30%. Early investigations of the utility of IR systems from different 
manufacturers have shown that a diagnostically acceptable CT of the 
abdomen and pelvis can be acquired at approximately 50% less dose than 
was previously possible with FBP. A recent prospective study investigating 
the diagnostic accuracy of low-dose CT, using hybrid IR, to detect active 
inflammation in Crohn’s disease with doses comparable to plain AXR (~1.4 
mSv), were as effective as conventional-dose CT in detecting clinically 
significant observations despite reduction in image quality.
In comparison to hybrid IR, pure iterative reconstruction algorithms 
result in diagnostically acceptable images de novo, which negates the 
requirement for blending with FBP data. Pure or model based iterative 
reconstruction (MBIR) is now commercially available and models the 
physical characteristics of the focal spot, the x-ray fan beam, the three-
dimensional interaction of the x-ray beam within the patient and the 
two-dimensional interaction of the x-ray beam within the detector. 
Pure IR is computationally demanding and despite the use of parallel 
processing technology, only three to four data sets can be reconstructed 
per hour, at present. Several clinical trials suggest that both low-dose 
and, more recently, conventional-dose abdominal CT reconstructed 
with pure IR are superior to hybrid IR and also outperform FBP in 
both subjective image quality indices and objective image noise scores, 
facilitating dose reductions of approximately 80% in selected clinical 
settings (Fig. 18.27).
In recent years, most CT manufacturers have incorporated IR 
into the latest generations of commercially available CT systems. This 
raises an issue of widespread availability of this technology, as it is not 
feasible for all medical centres to replace their equipment with newer 
CT machines. Also, the widespread availability of radiographers and 
radiologists trained in the optimal use of modern CT technology is 
challenging at many centres. Current research is growing towards the 
development of ‘vendor-independent’ algorithms that may be applied 
to FBP-reconstructed images obtained at lower doses to eliminate 
propagated image noise levels. These are known as ‘adaptive non-local 
means’ (ANLM) algorithms and often require less computational time 


CHAPTER 18  Current Status of Imaging of the Gastrointestinal Tract
479
Avoidance of exposure to ionising radiation and the capability to 
produce excellent soft-tissue contrast in multiple imaging planes, without 
the absolute need for administration of intravenous contrast agents, 
make MRI an excellent alternative for an increasing number of indica-
tions. MRI has been shown to supersede other investigations in certain 
abdominal: for example, complications and relapse of Crohn’s disease 
(MR enterography), characterisation of solid visceral lesions (MRI liver 
and kidneys) and biliary abnormalities Magnetic resonance cholangio-
pancreatography (MRCP).
Due to the aforementioned advantages, there is a growing demand 
for research for the potential expansion of the role of MRI in the acute 
abdomen. A meta-analysis incorporating 30 studies of 2665 patients 
investigating the diagnostic performance of MRI for the evaluation of 
acute appendicitis in the general population, as well as paediatric and 
gravid subgroups, demonstrated high sensitivity and specificity 
(95%–97%) in comparison with CT.
However, replacement of CT with MRI has been limited in such 
cases due to its relatively high cost, longer acquisition times and limited 
access to MRI in comparison with CT. Issues such as patient tolerance, 
claustrophobia and relative increased difficulty in performing MRI on 
critically ill patients also hinder its use. Therefore, the current consensus 
by the American College of Radiology (ACR) ACR appropriateness 
criteria is that MRI utilisation in the acute setting should be reserved 
for selected patient groups as mentioned above and, in specific cases, 
usually as a second-line investigation or problem-solving tool following 
an inconclusive US or CT study.
A retrospective study of MRI used in the investigation of acute 
abdominal pain during pregnancy demonstrated an accuracy of almost 
95% in identifying those who needed emergency intervention (Fig. 
18.28). Acute appendicitis is the commonest acute abdominal emergency 
encountered during pregnancy, with highest incidence in the second 
trimester. Other relatively common indications for MRI in pregnancy 
include acute cholecystitis, choledocholithiasis and ureterolithiasis. It 
also gives the advantage of excluding gynaecological disorders including 
ovarian torsion or pelvic abscess.
MRI has also been used in the evaluation of acute appendicitis, as well as 
Crohn’s disease, in young patients presenting with acute pain. For suspected 
appendicitis, graded compression US is usually the first-line imaging 
investigation and, when equivocal, an MRI of the pelvis is considered.
When choosing an MRI protocol for imaging of the acute abdomen, 
there is no fixed protocol or set of sequences. In many cases, MR protocols 
are tailored for the specific clinical question and to individual patients; 
in general, it is advised that a radiologist is on site to review studies and 
determine if further sequences are needed. Several institutes have proposed 
the following basic sequences in assessment of acute abdominal pain: 
T2 weighted single shot fast spin echo with and without fat saturation 
(T2 SSFSE +/− FS) for detecting inflammatory change and oedema, 
T2 weighted fast spin echo +/− short inversion recovery (T2 FSE +/− STIR) 
for superior anatomical delineation and T1 weighted gradient echo includ-
ing in and out-of-phase sequences. The use of IV contrast enhancement 
is also considered in special circumstances, particularly when abscess is 
suspected (diffusion weighted imaging (DWI) may also be useful).
Identifying the normal appendix on MRI may sometimes be difficult. 
The paucity of intra-abdominal fat in children and the presence of a 
gravid uterus can pose additional challenges. Nonetheless, imaging 
features in acute appendicitis are quite similar to those in CT: that is, 
the demonstration of a dilated appendix (>6 mm) with thickened 
hypointense walls. An appendicolith may be seen as a hypointense filling 
defect within the lumen. T2 fat-saturated or STIR sequences usually 
demonstrate high-signal intensity within the appendix and the sur-
rounding region, representing oedema and inflammatory change. Fluid 
collections and abscesses may also be identified (Fig. 18.29).
in comparison to de novo IR techniques. Early clinical studies have 
validated this method and results are promising. A study comparing 
ANLM to IR and, FBP suggests that image quality was not significantly 
compromised and, when applied with FBP, performance was as effective 
as IR techniques.
ROLE OF MRI IN THE ACUTE ABDOMEN
As previously discussed, current trends in CT imaging have led to 
increasing concern regarding patient radiation exposure, especially in 
patient subgroups with chronic illnesses who have the potential for 
high-lifetime cumulative exposures due to requirement for repeated CT 
imaging (e.g. Crohn’s disease and cystic fibrosis patients). Other groups 
for whom CT should be avoided include children and pregnant patients.
C
B
A
Fig. 18.27  Low-Dose Computed Tomography With Iterative Recon-
struction. A 36-year-old female patient (BMI 23.6) with a known diagnosis 
of Crohn’s disease. Axial contrast-enhanced images from low-dose 
computed tomography abdomen and pelvis (0.96 mSv) reconstructed 
with (A) filtered back projection, (B) hybrid iterative reconstruction 
and (C) pure iterative reconstruction show a progressive reduction in 
image noise and increase in image quality with more advanced iterative 
reconstruction.

## 2. Core Radiology High-Yield Notes (Pages 9-16)

### Key Visuals & Figures (Core Radiology)
![Core Figure](assets/core_p9_p9_img1.jpeg)

![Core Figure](assets/core_p9_p9_img2.jpeg)

![Core Figure](assets/core_p9_p9_img3.jpeg)

![Core Figure](assets/core_p9_p10_img1.jpeg)

![Core Figure](assets/core_p9_p11_img1.jpeg)

![Core Figure](assets/core_p9_p11_img2.jpeg)

![Core Figure](assets/core_p9_p11_img3.jpeg)

![Core Figure](assets/core_p9_p11_img4.jpeg)

![Core Figure](assets/core_p9_p11_img5.jpeg)

![Core Figure](assets/core_p9_p12_img1.jpeg)

![Core Figure](assets/core_p9_p12_img2.jpeg)

![Core Figure](assets/core_p9_p12_img3.jpeg)

![Core Figure](assets/core_p9_p12_img4.jpeg)

![Core Figure](assets/core_p9_p13_img1.jpeg)

![Core Figure](assets/core_p9_p13_img2.jpeg)

![Core Figure](assets/core_p9_p13_img3.jpeg)

![Core Figure](assets/core_p9_p14_img1.jpeg)

94
Hepatocellular carcinoma (HCC)
HCC in a cirrhotic liver: T2-weighted (top left 
image) and T1-weighted post-contrast late 
arterial phase (top right image) MRI shows a 
nodular external contour of the liver, consistent 
with cirrhosis. There is a T2 hyperintense, 
hypervascular mass in hepatic segment 2 (arrows), 
representing hepatocellular carcinoma.
Unenhanced CT (left image) shows the mass to be 
isoattenuating and barely perceptible (arrows).
Case courtesy Cheryl Sadow, MD, Brigham and 
Women’s Hospital.
• Hepatocellular carcinoma (HCC) is the most common primary liver tumor. Cirrhosis is 
the major risk factor for development of HCC. A hypervascular liver mass in a patient 
with cirrhosis or chronic hepatitis is an HCC until proven otherwise. 
• Alpha-feto protein (AFP) is elevated in approximately 75% of cases of HCC.
• Arterial phase enhancement is the characteristic imaging feature of HCC. However, 
between 10 and 20% of HCCs are hypovascular and thus slightly hypoenhancing 
relative to surrounding liver on arterial phase imaging. 
• The classic CT or MRI appearance of HCC is an encapsulated mass that enhances on 
arterial phase and washes out on portal venous phase. HCC may be difficult to detect on 
non-contrast or portal venous phase CT. On unenhanced MRI, HCC is characteristically 
slightly hyperintense on T2-weighted images relative to surrounding liver. 
The nodule in a nodule appearance describes an enhancing nodule within a dysplastic nodule and 
represents an early HCC.
• HCC is locally invasive and tends to invade into the portal and portal veins, IVC, and bile 
ducts. In contrast, metastases to the liver are much less likely to be locally invasive.
• Treatment options for HCC include partial hepatectomy, orthotopic liver 
transplantation, percutaneous ablation, and transcatheter embolization.
Fibrolamellar HCC
• 
Fibrolamellar carcinoma is a subtype of HCC that occurs in young patients without cirrhosis.
• The tumor tends to be large when diagnosed, but has a better prognosis than typical 
HCC. Unlike in HCC, AFP is not elevated.
• On MRI, fibrolamellar HCC is a large, heterogeneous mass. A fibrotic central scar 
is classic, which is hypointense on T1- and T2-weighted images (in contrast, focal 
nodular hyperplasia features a T2 hyperintense scar that enhances late). Capsular 
retraction may be seen in 10%.
• Unlike HCC, the fibrolamellar subtype does not have a capsule, although there may be 
a pseudocapsule of peripherally compressed normal hepatic tissue.


95
Hepatic metastases
• 
Although metastases are supplied by branches of the hepatic artery induced by tumoral 
angiogenesis, most metastases are hypovascular and best appreciated on portal venous 
phase (in contrast to HCC, which is hypervascular and best visualized on late arterial phase).
• Hypervascular metastases (best seen on arterial phase) classically include:
Neuroendocrine tumors, including pancreatic 
neuroendocrine tumors and carcinoid.
Renal cell carcinoma.
Thyroid carcinoma.
Melanoma.
Sarcoma.
• Colorectal and pancreatic adenocarcinoma metastases are typically hypovascular and 
can usually be diagnosed on portal venous imaging.
• Calcifications can be seen in mucinous colorectal tumors or ovarian serous tumors 
Calcification within a metastatic lesion may imply a better prognosis.
• 
On MRI, metastatic lesions tend to be hypointense on T1-weighted images and hyperintense 
on T2-weighted images. Blood products and melanin (as in melanoma) are T1 hyperintense.
• 
Pseudocirrhosis describes the macronodular liver contour resulting from multiple scirrhous 
hepatic metastases, which may mimic cirrhosis. Treated breast cancer is the most common 
cause of this appearance. Capsular retraction, although not always seen, is characteristic 
of pseudocirrhosis, and when present suggests pseudocirrhosis over cirrhosis.
Pseudocirrhosis due to 
multiple treated breast 
cancer metastases: Contrast-
enhanced CT shows numerous 
hypoattenuating hepatic lesions 
with a markedly nodular external 
hepatic contour (arrows) that 
resembles cirrhosis. 
Liver function in this patient 
remained normal.
Hepatic lymphoma
• 
Primary hepatic lymphoma is very rare. Lymphomatous involvement of the liver tends to 
be secondary to systemic disease, with associated splenomegaly and lymphadenopathy.
Epithelioid hemangioendothelioma
• Epithelioid hemangioendothelioma is a rare vascular malignancy that characteristically 
causes multiple spherical subcapsular masses than can become confluent. The 
individual masses may have a halo or target appearance.
• Epithelioid hemangioendothelioma is one cause of capsular retraction.
Hepatic capsular retraction
• Capsular retraction is a focal concavity of the normally convex external liver contour.
• Metastatic tumor (more commonly post-treatment).
• Fibrolamellar hepatocellular carcinoma (10% of cases of fibrolamellar HCC).
• Hepatocellular carcinoma (capsular retraction has been reported but is uncommon).
• Epithelioid hemangioendothelioma.
• Intrahepatic cholangiocarcinoma.
• Confluent hepatic fibrosis (wedge-shaped fibrosis seen in cirrhosis, most commonly the medial 
segment of the left hepatic lobe or the anterior segment of the right hepatic lobe).
differential diagnosis  
of capsular retraction


96
Benign liver masses
Focal nodular hyperplasia (FNH)
T1-weighted fat-saturated MRI
T2-weighted MRI
Late arterial post-contrast T1-weighted fat-sat MRI
Portal venous post-contrast T1-weighted fat-sat MRI
Delayed post-contrast T1-weighted fat-sat MRI
Focal nodular hyperplasia: T1-weighted MRI shows 
a barely perceptible mass in the right liver (yellow 
arrows) with a central low intensity scar (red arrow).
The mass is T2 isointense with the subtle suggestion 
of T2 hyperintense central scar (red arrow).
Arterial phase of enhancement shows avid 
enhancement with non-enhancement of the scar.
The mass washes out immediately on portal venous 
phase, with no change in intensity of the scar. 
Delayed T1-weighted image shows late 
enhancement of the central scar (red arrow).
Case courtesy of Cheryl Sadow, MD, Brigham and 
Women’s Hospital
• Focal nodular hyperplasia (FNH) is disorganized liver tissue with no malignant 
potential. It is primarily seen in asymptomatic women and is not associated with oral 
contraceptives.
• FNH has a characteristic central “scar” which does not contain fibrotic tissue and is 
therefore not a true scar. Instead, the central area consists of T2-hyperintense ductules 
and venules, and demonstrates delayed enhancement. FNH does not have a capsule.
• FNH can be difficult to see without contrast on CT and T1- and T2-weighted MRI 
sequences. FNH avidly enhances during the arterial phase, then washes out very 
quickly. The portal venous phase will often show just the unenhanced scar, which 
enhances late.
• 
Kupffer cells and bile duct epithelium are both present. Kupffer cells may be confirmed 
by a sulfur colloid study (1/3 of the time) and bile duct cells can be seen on a HIDA scan.


97
Hemangioma
Early arterial post-contrast T1-weighted image
Portal venous post-contrast T1-weighted image
Delayed post-contrast T1-weighted image
T2-weighted image
Hemangioma: Dynamic contrast-enhanced T1-weighted MRI (early arterial top left image to delayed 
bottom left image) shows a large mass (yellow arrows) in hepatic segment 7 demonstrating peripheral 
discontinuous nodular enhancement. There is progressively increasing centripetal enhancement 
towards the center of the lesion on delayed images. The signal intensity of the peripheral enhancement 
is similar to that of the aorta. On delayed images, there are a few central foci of nonenhancement (red 
arrows), consistent with cystic degeneration.
The hemangioma is hyperintense on the T2-weighted image (bottom right image) with subtle central 
areas of even higher signal centrally (red arrows), corresponding to the areas of cystic degeneration.
Case courtesy of Cheryl Sadow, MD, Brigham and Women’s Hospital.
• A hepatic hemangioma is a benign mass composed of disorganized endothelial-
lined pockets of blood vessels, supplied by a branch of the hepatic artery at the 
periphery.
• Hemangioma is more common in females and uncommon in cirrhosis. When a 
known hemangioma is sequentially followed in a patient with early cirrhosis, the 
hemangioma involutes as the liver becomes more cirrhotic.
• Hemangiomas may range in size from <1 cm to >10 cm. Giant hemangiomas tend to 
have a nonenhancing central area representing cystic degeneration.
• A virtually pathognomonic imaging feature is peripheral, discontinuous, progressive, 
nodular enhancement. The attenuation (or signal intensity on MR) of the 
enhancement is identical to the aorta and features gradual centripetal fill-in on later 
phases. 
• The unenhanced CT appearance of a hemangioma is a nonspecific hypoattenuating 
liver mass.


98
Hepatic adenoma
Hepatic adenoma: Coronal portal venous phase contrast-enhanced CT demonstrates a heterogeneously 
enhancing hypoattenuating mass (arrows) in the liver, which is a nonspecific appearance.
In- (left image) and out-of-phase (right image) MRI shows a mass in the right lobe of the liver (arrows) 
that demonstrates signal loss on out-of-phase images, consistent with a lesion containing intracellular 
lipid.
Case courtesy Cheryl Sadow, MD, Brigham and Women's Hospital.
• Hepatic adenoma is a benign hepatic neoplasm containing hepatocytes, scattered 
Kupffer cells, and no bile ducts. 
The absence of bile ducts makes a nuclear medicine HIDA scan a useful test to distinguish between 
focal nodular hyperplasia (which contains bile ducts and would be positive on HIDA) and a hepatic 
adenoma, which does not contain bile ducts.
• Adenomas are much more common in females, especially with prolonged oral 
contraceptive use. When seen in males, adenoma may be associated with anabolic 
steroids.
• Adenomas have a relatively high risk of hemorrhage, which is often the presenting 
symptom. For this reason, incidentally discovered adenomas are usually resected.
• Multiple hepatic adenomas are seen in von Gierke disease (type I glycogen storage 
disease).
• A pseudocapsule may be present, which tends to enhance late.
• 
Adenomas lack portal venous drainage and thus are hypervascular on arterial phase. The 
presence of microscopic fat, when present, is best seen on in- and out-of-phase MRI. 
Intralesional hemorrhage may cause T1 hyperintensity. Adenomas may be difficult to 
differentiate from other hypervascular liver lesions in the absence of fat or hemorrhage.


99
Vascular liver disease
Budd-Chiari
• 
Budd–Chiari is hepatic venous outflow obstruction, which can be thrombotic or non-
thrombotic. Budd–Chiari may be due to hypercoagulative states including hematological 
disorders, pregnancy, oral contraceptives, malignancy, infection, and trauma. It is very rare 
to have primary Budd–Chiari due to congenital hepatic vein anomaly, as pictured below.
• Acute Budd–Chiari presents with 
a clinical triad of hepatomegaly, 
ascites, and abdominal pain. 
• Direct vascular findings include 
lack of flow within hepatic veins, 
thrombus in the hepatic veins/IVC, 
and the formation of  
collateral vessels.
• Acute intraparenchymal findings 
include an edematous peripheral 
liver with sparing of the caudate 
lobe. The caudate is spared as it 
drains directly into the IVC. 
• Progressive liver failure may result 
in chronic disease, producing 
caudate lobe hypertrophy and 
atrophy of peripheral liver with 
prominent regenerative nodules.
Congenital Budd–Chiari: Axial contrast-enhanced CT shows 
massive enlargement of the caudate lobe (yellow arrows) 
and the right posterior segment. There is atrophy of the 
left lobe and right anterior segments of the liver. Collateral 
venous drainage in the periphery of the liver is seen as 
geographic peripheral hyperenhancement (red arrows). 
The causative congenital hepatic vein anomaly is not 
visualized at this level.
Case courtesy Cheryl Sadow, MD, Brigham and Women's 
Hospital.
Veno-occlusive disease
• 
Veno-occlusive disease (VOD) is destruction of post-sinusoidal venules, with patent hepatic 
veins. VOD is seen in bone marrow transplant patients, possibly due to chemotherapy.
• Imaging findings are nonspecific. Periportal edema, narrowing of the hepatic veins, 
hepatomegaly, and heterogeneous hepatic enhancement have been reported. In 
contrast to Budd–Chiari, the caudate lobe is not spared.
Cardiac hepatopathy
• Cardiac hepatopathy is passive hepatic congestion from heart failure, constrictive 
pericarditis, or right-sided valvular disease, which ultimately may lead to cirrhosis. 
• Imaging clues are enlarged hepatic veins and IVC, with reflux of intravenous contrast 
from the right atrium into the IVC and hepatic veins. The liver is typically enlarged and 
demonstrates mottled enhancement. Ascites is usually present.
Congenital cystic liver disease
Biliary hamartomas (von Meyenburg complexes)
• Biliary hamartomas are incidental small cystic hepatic lesions that do not communicate 
with the biliary tree, caused by embryologic failure of normal bile duct formation. 
• Biliary hamartomas tend to be smaller and more irregularly shaped than simple cysts.
Autosomal dominant polycystic liver disease (ADPLD) 
• 
40% of patients with autosomal dominant polycystic kidney disease (ADPKD) have a similar 
disease process in the liver, called ADPLD. Even in severe disease, hepatic failure is rare.
• On imaging, there are innumerable nonenhancing simple cysts throughout the liver. 


100
Liver trauma
Overview of liver trauma
• The liver is the second most commonly injured solid organ due to blunt trauma, second 
to the spleen. The CT description and grading of liver injury is similar to splenic injury.
• The American Association for the Surgery of Trauma (AAST) classification describes 
hepatic injury based on findings at laparotomy.
• The MDCT hepatic injury grading scale is based on CT findings and is more commonly 
used by radiologists. It is similar to the MDCT grading scale for splenic trauma.
MDCT grading of hepatic injury
• Grade I: Superficial laceration or subcapsular hematoma <1 cm in size.
• Grade II: Laceration or subcapsular/intraparenchymal hematoma >1 and <3 cm in size.
• Grade III: Laceration or subcapsular/intraparenchymal hematoma >3 cm in diameter.
• Grade IV: Massive hematoma >10 cm, or destruction/devascularization of one hepatic lobe.
• Grade V: Destruction or devascularization of both hepatic lobes. 
Biliary imaging
Introduction to MRCP
Magnetic resonance cholangiopancreatography (MRCP) overview
• Magnetic resonance cholangiopancreatography (MRCP) is an abdominal MRI 
acquired with heavily T2-weighted sequences that increase the contrast between T2 
hyperintense stationary fluid in the biliary tract and surrounding structures.
• Fast spin echo sequences are most commonly used for MRCP acquisition. Various 
techniques can be employed to optimize imaging including breath-hold sequences 
and respiratory-triggered sequences. 
• Heavily T2-weighted sequences primarily image the biliary tree. 
• Sequences with intermediate T2 (TE 80–100 ms) are best suited for visualization of 
the biliary ductal system and surrounding tissue, in particular to evaluate extraluminal 
structures.
• Advantages of MRCP over ERCP include:
MRCP has the ability to see extra-luminal findings.
MRCP can visualize excluded (obstructed) ducts.
MRCP is non-invasive.
• Disadvantages of MRCP compared to ERCP include:
MRCP does not allow for concurrent therapeutic intervention.
MRCP does not actively distend the biliary ductal system with contrast.
MRCP has worse spatial resolution compared to ERCP.
• Contrast-enhanced MRCP can also be performed with fat-saturated T1-weighted 
imaging after injection of gadolinium contrast agents that have biliary excretion, such 
as gadoxetic acid disodium (Eovist, Bayer Healthcare, Germany) and gadobenate 
dimeglumine (Multihance, Bracco Diagnostics). These agents shorten T1 relaxation, 
resulting in T1 hyperintense biliary fluid, but require a 20–45 minute delay prior to 
imaging to allow time for biliary excretion.
MDCT
hepatic trauma


101
Choledochal cysts
Overview and Todani classification of choledochal cysts
CBD
LHD
RHD
GB
cystic
duct
CHD
CBD
LHD
RHD
GB
CD
CHD
normal bile duct anatomy
Type I choledochal cyst:
Fusiform common bile duct dilation
CBD
LHD
RHD
GB
CD
CHD
Type II choledochal cyst:
Extrahepatic saccular dilation
CBD
LHD
RHD
GB
CD
CHD
Type III choledochal cyst:
Dilation of intraduodenal bile duct
CBD
LHD
RHD
GB
CD
CHD
Type IV choledochal cyst:
Multiple segments dilated
CBD
LHD
RHD
GB
CD
CHD
Type V choledochal cyst:
Intrahepatic dilation = Caroli disease
sphincter
of Oddi
Most common, makes up ~50% of choledochal cysts
Type IVA: Intra and extrahepatic dilation (pictured)
Type IVB: Extrahepatic dilation only
GB, gallbladder
CHD, common hepatic duct
CBD, common bile duct
RHD, right hepatic duct
LHD, left hepatic duct

## 3. Crack the Core Exam Review (Prometheus Lionhart M.D. - Pages 181-192)

### Key Visuals & Figures (Crack the Core)
![Crack Figure](assets/crack_v1_p181_p181_img1.jpx)

![Crack Figure](assets/crack_v1_p181_p182_img1.jpx)

![Crack Figure](assets/crack_v1_p181_p183_img1.jpx)

![Crack Figure](assets/crack_v1_p181_p184_img1.jpx)

![Crack Figure](assets/crack_v1_p181_p185_img1.jpx)

![Crack Figure](assets/crack_v1_p181_p186_img1.jpx)

![Crack Figure](assets/crack_v1_p181_p187_img1.jpx)

![Crack Figure](assets/crack_v1_p181_p188_img1.jpx)

![Crack Figure](assets/crack_v1_p181_p189_img1.jpx)

![Crack Figure](assets/crack_v1_p181_p190_img1.jpx)

![Crack Figure](assets/crack_v1_p181_p191_img1.jpx)

![Crack Figure](assets/crack_v1_p181_p192_img1.jpx)

d v . Solving Cases Using Buzzwords
When I say “Post Term Baby, ” 
You Say Meconium Aspiration
When I say "C-Section, ”
You say Transient Tachypnea
When I say “Maternal Sedation ’ 
You say Transient Tachypnea
When I say “Premature ”
You say RDS
How this could work:
Blah Blah Blah , Post Term Delivery of a
beautiful baby girl. What is the diagnosis?
(A) RDS
(B) Transient Tachypnea
(C) Meconium Aspiration
Solving Cases Using Lung Volumes:
High (flat diaphragms):
• Meconium Aspiration
• Transient Tachypnea
• Non BH Neonatal Pneumonia
Low:
•Surfactant Deficiency (no pleural effusion) 
•Beta-Hemolytic Pneumonia (gets pleural effusions)
Y
How this could work:
Blah Blah Blah , This Picture o f a beautiful baby 
girl. What is the diagnosis?
(A) RDS
(B) Transient Tachypnea
(C) Meconium Aspiration
182


-Congenital Chest-
Pulmonary Hypoplasia: “Tiny Lung’
This is the situation where the lung(s) look tiny or incompletely developed. It can occur from primary 
reasons, but the secondary causes seem to lend themselves more readily to multiple choice questions.
You can think about secondary causes as either:
(A) Things inside the chest pushing on the lungs during development (most commonly a congenital 
diaphragmatic hernia / bowel in the chest, but sometimes from a neuroblastoma, giant congenital 
heart, or sequestration)
(B) Things outside the chest pushing on the lungs during development 
(classically a fucked up skeleton / ribs - as you might see in a short 
rib dwarf like Jeune syndrome “asphyxiating thoracic dystrophy,” but 
sometimes a large intra-abdominal mass compressing the thorax)
(C) Things outside the chest fucking with normal lung development 
(classically low fluid “oligohydramnios” ). Remember, the 
developing baby has to breath in the amniotic fluid for normal lung 
development. Anything that drops fluid (premature rupture of 
membranes. Potter sequence, renal problems) will mess up the lungs.
OB Ultrasound Buzzwords:
’Reduced Thoracic Circumference (TC)
’Fetal Lung: Head Ratio < 1
Potter Sequence
No Kidneys 
♦
No Pee 
No Amniotic Fluid 
Hypoplastic Lungs
Congenital Diaphragmatic Hernia (CDHs):
Most commonly they are Bochdalek type. B is in the Back - they are typically posterior and to the 
left. The appearance on CXR is usually pretty obvious.
Trivia:
•Usually in the Back , and on the left (Bochdalek)
•If it’s on the right - there is an association with GBS Pneumonia 
•Mortality Rate is related to the degree of pulmonary Hypoplasia 
•Most have Congenital Heart Disease 
•Essentially all are malrotated
Gamesmanship
•One trick is to show the NG tube curving into the chest.
LARGE Congenital 
Diaphragmatic Hernia
Buncha Bowel in the 
Chest Smashing a Lung
Pulmonary Hypoplasia of 
the Smashed Lung
Bronchogenic Cysts:
Typically an incidental finding. They are generally solitary and unilocular. They typically do NOT 
communicate with the airway, so if they have gas in them you should worry about infection.
183


Bronchopulmonary Sequestration
The easiest way to think about these things is “extra lung that is NOT connected to the airways or 
vasculature normally.” Some people will call them “accessory lung tissue.” Other people will call 
them “bronchopulmonary foregut malformations” or BPFMs, but those people tend to be weirdos. The 
kind of people who send out Christmas cards with the dog dressed as Santa.
Sequestrations Have:
- NO communication with the airway
- NO communication with the pulmonary arteries
- They USUALLY have an Aortic Feeder Vessel
These are grouped into intralobar and extralobar with the distinction being which has a pleural 
covering (which you can NOT see on imaging). The venous drainage is different (intra to 
pulmonary veins, extra to systemic veins). You can NOT tell the difference radiographically.
The practical difference is age and presentation.
Intralobar
Extralobar
More Common (75%)
Less Common (25%)
Presents in Adolescence
Presents in Infancy
Recurrent Infections 
(bacteria migrates in from pores of Kohn)
Respiratory Distress or Cyanosis 
(often related to associated congenital 
anomalies)
Rare to Have Associated 
Congenital Anomalies
Associated Congenital Anomalies 
- ‘Extra’for ‘Extra’things- 
(CCAMs, congenital diaphragmatic hernia, 
vertebral anomalies, congenital heart disease, 
pulmonary hypoplasia)
Most Common (60%) in the Left Lower Lobe, 
Posterior Segment. 40% in the RLL
Uncommon in the Upper Lobes.
90% in the Left Lower Lobe
10% Below the Diaphragm 
“subdiaphragmatic”
No Pleural Cover 
you can’t see that shit on CT or MR
Has its own pleural cover 
you can’t see that shit on CT or MR
*The pleural covering is protective against 
infection, which is why they rarely get infected
Pulmonary Venous Drainage
Systemic Venous Drainage
Gamesmanship: I say recurrent pneumonia in same area, you say intralobar sequestration.
184


Congenital Lobar Emphysema (CLE)
The idea behind this one is that you have bronchial pathology (maybe atresia depending on what 
you read), that leads to a ball-valve anomaly and progressive air trapping. On CXR, it looks 
like a lucent, hyper-expanded lobe.
Trivia:
• It’s not actually emphysema - just air trapping secondary to bronchial anomaly
• It prefers the left UPPER lobe (40%)
• Treatment is lobectomy
Gamesmanship: The classic way this is shown in case conference or case books is with a series 
of CXRs. The first one has an opacity in the lung (the affected lung clears fluid slower than 
normal lung). The next x-ray will show the opacity resolved. The following x-ray will show it 
getting more and more lucent. Until it’s actually pushing the heart over.
Note the mass 
effect on the heart
Congenital Cystic Adenomatoid Malformation (CCAM)
- (Other Aliases Include - C P A M )
As the name suggests it’s a malformation of adenomatoid stuff 
that replaces normal lung. Most of the time it only involves one 
lobe. There is no lobar preference (unlike CLE which favors the 
left upper lobe). There are cystic and solid types (type 1 cystic 
is the most common -70% ). There is a crop of knuckle heads 
who want to call these things CPAMs, which I’m sure is 
evidence based and will really make an impact in the way these 
things are treated. As such, you should be ready for them to be 
called CPAMs on the exam, don’t let that trip you up. CCAMs 
communicate with the airway, and therefore at least components 
of them can fill with air. Most of these things (like 90%>) will 
spontaneously decrease in size in the third trimester. The 
treatment (at least in the USA) is to cut these things out, because 
of the iddy bitty theoretical risk of malignant transformation 
(pleuropulmonary blastoma, rhabdomyosarcoma).
Q: What if you see a systemic arterial feeder (one coming o ff the aorta) going to the CCAM ? 
A: Then it’s not a CCAM, it’s a Sequestration. — mumble to yourself “nice try assholes”
Schematic of a the most 
common “look” for a CCAM / 
CPAM. They tend to have 
large cysts, surrounded by 
smaller cysts.
185


Left Upper Lobe:
Think Congenital Lobar 
Emphysema (CLE) first
But, remember CCAI\/I has no 
lobar prevalence, so it can be 
anywhere
Left Lower Lobe:
Think Sequestration First
Congenital Diaphragmatic 
Hernia (CDHs) favors this 
side too
Case 1. Newborn with congenital heart disease
A. Intralobar Sequestration
B. Extralobar Sequestration
C. Congenital Lobar Emphysema
Case 2. 10 year old with recurrent pneumonia
A. Intralobar Sequestration
B. Extralobar Sequestration
C. Congenital Lobar Emphysema
**Intralobar is seen older kids,
**Extralobar is seen in infants with co-morbids 
** CLE is in the upper lobe
186


-Primary Lung Tumors-
THIS vs THAT: Primary Lung Tumor vs Congenital Malformation:
As a general rule, developmental / congenital lung lesions will be present on the 
mid-second trimester US. For the purpose of multiple choice, if the history tells 
you that the 2nd Trimester US was normal and they show you a mass - think 
Primary Tumor. If instead they tell you (or show you) a lung mass on the second 
trimester US - think Congenital Malformation (CPAM - etc..). There are 
exceptions to this rule - I’m not going to get into it and confuse the issue. This is a 
“general rule” for gamesmanship.
Normal 2nd 
Trimester US
+
Infant with 
Lung Tumor
Primary 
Lung Tumor
Pleuropulmonary Blastoma (PPB) - This is the most 
common primary lung malignancy in children. They can look a 
lot like CCAMs and even have different types (cystic, mixed, 
solid) - but should be absent on the second trimester US. These 
things are usually right sided, pleural based, and without chest 
wall invasion or calcifications. No rib invasion (helps 
distinguish it from the Askin /Ewing Sarcoma o f the Chest Wall - 
if they won't tell you the age), No calcification. The more solid 
types can have mets to the brain and bones. The cystic type seem 
to occur more in kids less than a year old, and be more benign.
PPB
Big Fucking Mass (B.F.M.) 
in the chest of a 1-2 year old
Shouldn’t have an eaten-up 
rib (Askin tumors often do)
10% of the time they have a 
multilocular cystic nephroma.
Inflammatory Myofibroblastic Tumor (IMT) - This is the most cormnon primary lung 
mass in children. It is benign (PPBs are malignant). These are solid masses, typically lobulated and 
often calcified. They have a lower lobe predominance. The tend to look like fluid on MR (T2 bright) 
because they are composed of “myxoid” stroma. It can look like a sequestration (given the arterial 
supply) or the solid types of PPB.
-Catheters/Lines-
Umbilical Venous Catheter (UVC) - AUVC passes from the 
umbilical vein to the left portal vein to the ductus venosus to a hepatic vein 
to the IVC. You don’t want the thing to lodge in the portal vein because 
you can infarct the liver (or cause portal hypertension).
Things to know about UVCs:
• The ideal spot is at the IVC - Right Atrium junction.
• Clot forming in a portal vein branch can cause lobar atrophv
• Development of a "Cystic Liver Mass" (Hematoma) can suggest UVC 
erosion into the liver.
Umbilical Artery Catheter (UAC) - AUAC passes from the 
umbilicus, down to the umbilical artery, into an iliac artery than to the 
aorta. Positioning counts, as the major risk factor is renal arterial 
thrombosis. You want to avoid the renal arteries by going high (T8-T10), 
or low (L3-L5)
Things to know about UACs:
• It goes down first
• It should be placed either high (T8-T10) or low (L3-L5)
• Should stay left of midline on AXR (aorta on the left)
• Omphalocele is a contraindication
187


ECHO - Extracorporeal Memdrane Oxygenation
Neonatologists primarily use this device to torture sick babies - hopefully into revealing the 
various government secrets they have stolen, or the location of their organization’s 
underground lair. “Enhanced interrogation” or “temporizing measure of last resort,” they call 
it - to get around the Geneva Conventions.
Oh you want to pretend you can’t talk? Get the ECMO catheters!
Alternatively, it can be used as a last resort in neonatal sepsis, severe SSD, and meconium 
aspiration. Actually, in cases of meconium aspiration ECMO actually does work 
(sometimes).
Types:
There are two main types; (1) Veno-Arterial “V-A”, 
and (2) Veno-Venous “V-V”
In both cases deoxygenated blood is removed from the 
right atrium and pumped into a box (artificial lung) to 
get infused with oxygen. The difference is in how it is 
returned.
In V-A, blood goes back to the Aorta (you can see 
why this would help rest the left ventricle). The 
catheter is usually placed at the origin of the 
innominate or “overlying the arch.”
In V-V blood goes right back into the right atrium. In 
this situation even if the lungs were totally clogged 
with shit (meconium aspiration) and no oxygen 
exchange was happening it wouldn’t matter because 
the blood that is being pumped (RA -> RV -> 
Pulmonary Artery) already has oxygen in it.
VenoArterial
“V-A”
Catheter
Position;
RA + Aorta (near 
the origin of 
the innominate 
artery)
Veno Venous
“V_V”
Catheter 
Position; 
R A + R A 
“Dual Lumen”
Heart + Lung 
Support
Carotid artery 
and Rigiit 
Jugular Vein are 
“Sacrificed” to 
tile Volcano God 
in the hopes of a 
plentiful harvest.
Lung Support
188


ECHO - Extracorporeal Membrane Oxygenation - Condnued
Things to Know:
• Lung White Out = Normal. Mechanism is variable depending on who you asked. The way 
I understand it is that the airway pressure suddenly drops off causing atelectasis, plus you 
have a change in the circulation pattern that now mimics the fetal physiology (mom = 
artificial lung). Resulting oxygen tension changes lead to an edema like pattern. A multiple 
choice trick could be to try and make you say it is worsening airspace disease, or reflects the 
severity of the lung injury. Don’t fall for that. It’s an expected finding.
• Consequences of V-A. I mentioned on the prior page that they typically ligate the carotid 
when they place the Arterial catheter. No surprise that they will be at increased risk for 
neurologic ischemic complications as a result.
• Crucial Complication = Hemorrhage. The combination of anticoagulation (necessary in 
ECMO) and being sick as stink puts these kids at super high risk for head bleeds. This is 
why they will get screened for germinal matrix hemorrhage prior to being placed on ECMO 
and then routinely screened with head ultrasounds (expertly read by the second year resident 
on call).
Catheter Position Gamesmanship:
I think there are two likely ways a multiple choice question could be structured related to 
ECMO catheter position. The first would be to show you a series of daily radiographs with the 
latest one demonstrating migration of one or both catheters. Thats the easy way to do it.
The sneaky way would be to show you the 
catheter with the lucent distal end and the dot 
marker on the tip. This would be particularly 
evil as there are tons of different catheter 
brands and looks, but if I was going to try and 
trick you, this would be the way that I would do 
it.
In this case, the venous catheter looks falsely 
high if judged by the lucent tip, but that round 
metallic marker (near the black arrow) shows 
the tip in the RA.
The arterial catheter “overlies the region of the 
aortic arch,” which is normal.
189


-Special Situations in Peds Ciiests-
Viral - In all ages this is way more common than bacterial infection. Peribronchial edema is the 
buzzword for the CXR finding. “Dirty” or “Busy” Hilum. You also end up with debris and mucus in 
the airway which causes two things (1) hyperinflation and (2) subsegmental atelectasis. Respiratory 
Syncytial Virus (RSV) - This will cause the typical non-specific viral pattern as well. However, 
there is the classic testable predilection to cause a segmental or lobar atelectasis — particularly in the 
right upper lobe.
Round Pneumonia - Kids get round pneumonia. They love to show 
this, and try to trick you into thinking it’s a mass. Younger than 8 you are 
thinking round pneumonia, round pneumonia, round pneumonia - with S. 
Pneumonia being the culprit. The PhD trivia is that these occur because you 
don’t have good collateral ventilation pathways. Round pneumonia is 
usually solitary, and likes the posterior lower lobes. Take home message: No 
CT to exclude cancer, just get a follow up x-ray.
Neonatal atypical peripheral atelectasis (NAPA) - It is best 
to think about this as a cousin or uncle of Round Pneumonia (they are in the 
same family). It is essentially the same thing except it is peripheral. The 
classic look is a round, pleural based “mass” in the apex of the lung. 
Similarly to the “round pneumonia” this is a transient finding and will 
resolve as the primary process improves.
Lipoid Pneumonia - Classic history is a parent giving their newborn a teaspoonful of olive oil 
daily to cultivate “a spirit of bravado and manliness. ” Although this seems like a pretty solid plan, and
I can’t fault their intentions - it’s more likely to result in chronic fat aspiration. Hot Sauce is probably a 
better option. Most people will tell you that bronchoalveolar lavage is considered the diagnostic 
method of choice. CXR is nonspecific - it is just airspace opacities. CT is much more likely to be the 
modality used on the exam. The classic finding is low attenuation (-30 to -100 HU) within the 
consolidated areas reflecting fat content.
Bronchial Foreign Body:
The key concept is that it causes air trapping. 
The lung may look more lucent (from air 
trapping) on the affected side. You put the 
affected side down and it will remain lucent 
(from air trapping). Another random piece of 
trivia is that under fluoro the mediastinum will 
shift AWAY from the affected side on 
expiration.
Key Point: A normal inspiratory CXR is meaningless. Don’t forget that the crayon / green bean is going 
to be radiolucent. You need expiratory films to elicit air trapping. Normally, the bottom lung is gonna 
turn white (move less air). If there is air trapping the bottom lung will stay black.
190


Swyer Janies - This is the classic unilateral lucent lung. It typically occurs after a viral lung 
infection in childhood resulting in post infectious obliterative bronchiolitis. The size of the affected 
lobe is smaller than a normal lobe (it’s not hyper-expanded).
Papillomatosis - Perinatal HPV can cause these soft tissue masses within the airway and lungs. 
It’s also seen in adults who smoke. "Multiple lung nodules which demonstrate cavitation ” is the 
classic scenario. Some testable trivia includes the 2% risk of squamous cell cancer, and that 
manipulation can lead to dissemination. The appearance of cysts and nodules can look like LCH 
(discussed more in the thoracic chapter), although the trachea is also involved.
Sickle Cell / Acute Chest - Kids with sickle cell can get “Acute chest.” Acute chest actually 
occurs more in kids than adults (usually between age 2-4). This is the leading cause of death in sickle 
cell patients. Some people think the pathology is as such: you infarct a rib -> that hurts a lot, so you 
don’t breathe deep -> atelectasis and infection. Others think you get pulmonary microvascular 
occlusion and infarction. Regardless, if you see opacities in the CXR of a kid with sickle cell, you 
should think of this.
Gamesmanship (how do you know it is sickle cell?)
• Kid with Big Heart
• Kid with bone infarcts (look at the humeral heads)
• Kid with H shaped vertebra (look on lateral)
• Cholecysectomy Clips (look at right upper abdomen)
Cystic Fibrosis- So the sodium pump doesn’t work and 
they end up with thick secretions and poor pulmonary 
clearance. The real damage is done by recurrent infections.
Things to know:
• Bronchiectasis
(begins cylindrical and progresses to varicoid)
• It has an apical predominance 
(lower lobes are less involved)
• Hyperinflation
• They get Pulmonary Arterial Hypertension
• Mucus plugging (finger in glove sign)
• Men are infertile (vas deferens is missing)
Primary Ciliary Dyskinesia - The motile part of 
the cilia doesn’t work. They can’t clear their lungs and get 
recurrent infections. These guys have lots of bronchiectasis 
just like CF. BUT, this time it’s lower lobe predominant 
(CF was upper lobe).
Things to know:
• Bronchiectasis (lower lobes)
• 50% will have Kartageners (situs inversus).
So, 50% will not
• Men are infertile (sperm tails don’t work)
• Women are sub-fertile (cilia needed to push eggs around)
CF Related Trickery
Fatty Replaced Pancreas on CT
Abdominal Films with 
Constipation
Biliary Cirrhosis (from blockage 
of intrahepatic bile ducts), and 
resulting portal HTN
THIS vs THAT:
Cystic
Fibrosis
Upper Lobe 
Predominant - 
Brochiectasis
Infertile - Men are 
Missing the Vas 
Deferens
Primary 
Ciliary 
Dyskinesia
Lower Lobe 
Predominant - 
Bronchiectasis
Infertile - Men’s 
Sperm Don’t Swim 
For Shit
191


S E C T I O N 6:
M E D I A S T IN A L M A S S E S
Anterior:
Normal Thymus: This is the most common mediastinal 
“mass.” It’s terribly embarrassing to call a normal thymus a 
mass, but it can actually be tricky sometimes. It can be pretty 
big in kids less than 5 (especially in infants). Triangular 
shape of the thymus is sometimes called the “sail sign.” Not 
to be confused with the other 20 sail signs in various parts of 
the body, or the spinnaker sail sign, which is when 
pneumomediastinum lifts up the thymus.
That Asshole is Guilty!
Things that make you think the 
thymus is a cancer!
• Abnormal Size for patients Age 
(really big in a 15 year old)
• Heterogenous appearance
• Calcification
• Compression of airway or 
vascular structure
Thymic Rebound: In times of acute stress (pneumonia, radiation, chemotherapy, bums), the 
thymus will shrink. In the recovery phase it will rebound back to normal, and sometimes larger 
than before. During this rebound it can be PET avid.
Lymphoma: This is the most common abnormal mediastinal mass in children (older 
children and teenagers). Lymphoma vs Thymus can be tricky. Thymus is more in kids under 10, 
Lymphoma is seen more in kids over 10. When you get around age 10, you need to look for 
cervical lymph nodes to make you think lymphoma. If you see calcification, and the lesion has 
NOT been treated you may be dealing with a teratoma. Calcification is uncommon in an untreated 
lymphoma.
Complications: Compression o f SVC, Compression o f Pulmonary Veins, Pericardial Effusion, 
Airway Compression.
ALL / Leukemia - can appear very similar to Lymphoma (soft tissue mass in the anterior 
mediastinum). In this scenario, most people will tell you that Lymphoma can NOT be 
differentiated from Leukemia on imaging 
alone.
Germ Cell Tumor (GCT): On
imaging, this is a large anterior mediastinal 
mass arising from or at least next to the 
thymus. It comes in three main flavors, each 
of which has a few pieces of trivia worth 
knowing:
1- Teratoma - Mostly Cystic, with fat and 
calcium
2 - Seminoma - Bulky, solid and lobulated. 
“Straddles the midline”
3 - NSGCT - Big and Ugly - Hemorrhage 
and Necrosis. Can get crazy and invade the 
lung.
I say, Extra Gonadal Germ Cell Tumor,
You Say Klinefelter’s Syndrome (47XXY)
Klinefelter patients have the worst syndrome 
ever. They have small penises, they get male 
breast cancer, and as if things couldn’t possibly 
get worse... they get germ cell tumors in their 
chest. In fact, they are at 300x the risk of 
getting a GCT. Pineal gland Germ Cells have 
also been reported in Klinefelter patients, giving 
them vertical gaze palsy. In that case, they can’t 
even look up to the sky and say “Why God* ?! 
Why Me!? Why Klinefelter's!?”
**God, Allah, Mother Earth, Celestial Deity NOS
192


Middle
Lymphadenopathy - Middle mediastinal lymphadenopathy is most often from 
granulomatous disease (TB or Fungal), or from lymphoma.
M e d iastin ai A d e n o p a tiiy T rivia:
Mononucleosis
Cause: EBV (-90%), CMV (-10%)
Classic Scenario: Adolescent with hilar adenopathy, splenomegaly, 
and fatigue.
Trivia: Rash after Antibiotics (Amoxicillin)
Trivia: “No sports for 3 weeks” - to avoid splenic injury
Primary TB
Distribution of nodes in usually unilateral, right hilar, right paratracheal 
Lower and Middle lobe consolidation is common
Histoplasmosis
Midwest and Southeast United States 
Most have normal CXRs 
Can have hilar adenopathy
Coccidioidomycosis
Southwest United States
Usually looks like consolidation and nodules
Can have hilar adenopathy
Lymphoma
Often cited as the “most common” anterior mediastinal mass in a kid. 
Hilar involvement (usually bilateral) is more common with Hodgkin
Sarcoid
Uncommon in children — it usually presents in the early-mid 20s. 
Case reports of early onset Sarcoid exist.
Duplication Cysts - These fall into three categories (a) bronchogenic, (b) enteric, 
(c) neuroenteric. The neuroenterics are traditionally posterior mediastinal.
• Bronchogenic - water attenuation - close to the trachea or bronchus. Trivia:
• Tend to be middle mediastinal (70%), the rest are in the hilum
• Typically filled with mucus or fluid
• Enteric I Esopiiageai - water attenuation close to the esophagus (lower in the 
mediastinum). Trivia:
• Abutment of the esophagus is the key finding.
• Can communicate with the lumen of the esophagus - and have air/fluid levels.
• Usually on the right, involving the distal esophagus
• Can be middle or posterior mediastinal in location
• Second most common GI lumen duplication cyst (distal ileum #1)
193

