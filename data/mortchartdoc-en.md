---
title: Documentation
author: Karl Pettersson
lang: en-US
mainlang: en-US
classoption: a4paper
fontsize: 12pt
...

#Introduction

The aim of this site is to give comprehensible information about trends for
cause-specific mortality in different population. Charts may be viewed or
downloaded after choice of population, age group and cause of death group. The
measures shown in the charts have been calculated using open data from
@whomort, but the WHO are not responsible for any content on the site.

There are several other websites with visualizations of mortality trends. One
of the most advanced is @ihmecodviz, which contains data for all countries in
the world, and uses complicated algorithms to adjust for uncertainties in the
underlying data. On this website, the charts are generated dynamically, and the
sites may sometimes be slow. Moreover, the visualizations do not go further
back in time than 1980, while @whomort has data available from 1950, for
several populations. @mortrends is a website with a great number of static
charts based on @whomort. This website is no longer maintained, however, because
its creator has died.

This website can be used for fast and easy rendering of visualizations
mortality trends from the 1950s until recent years. The site contains no
server-side code with any database connections. The scripts and data files used
to generate the charts and the site are available via a
[GitHub repo](https://github.com/klpn/Mortchartgen.jl).

#Measures of mortality

*Mortality rate* is a fundamental measure of mortality. For a cause of death
$c$, a population $x$ during a time $t$, the mortality rate due to $c$ in $x$
during $t$, $m_{c,t}(x)$, is calculated as $m_{c,t}(x)=n_{c,t}(x)/p_t(x)$,
where $n_{c,t}$ is the number of deaths due to $c$ during $t$, and $p_t$ is the
mean population during $t$. If $x$ is a broad age interval, mortality rates for
many causes will often be influenced by trends in the age distribution. If the mean
age in a population increases, this will often increase mortality rates from
age-related causes such as cancer, circulatory disease and dementia. @whomort
has data over population and number of deaths in 5-year intervals; using these,
it is possible to calculate mortality rates which are not sensitive to such
trends @whomort has data over population and number of deaths in 5-year
intervals; using these, it is possible to calculate mortality rates which are
not very sensitive to such trends, and therefore gives a better measure of
direct effects of things as healthcare and environmental factors on mortality.
However, mortality rates in narrow age intervals, may be sensitive to random
variations, especially in small populations. Therefore, this website shows
unweighted averages of mortality rates over the 5-year intervals included in
wider age intervals (15--44, 45--64, 65--74 and 75--84 years). Moreover, there
are charts showing proportions of deaths for the different causes for all ages
and ages below and above 85 years (this can be used to judge whether trends in
the population as a whole are related to trends at the oldest ages, whose
interpretation may be problematic).

Available data has a binary classification in females and males. For most
causes, mortality rates differ significantly between females and males, and the
ratio between sex-specific rates varies over time for many causes, such as
ischemic heart disease and lung cancer. Because of this, all charts show
sex-specific trends.

#Underlying causes and artificial trends

All data is about so-called *underlying causes of deaths*. For each death,
exactly one underlying cause is registered in the official statistics of the
different populations. It is defined as "(a) the disease or injury which initiated
the train of morbid events leading directly to death, or (b) the circumstances of
the accident or violence which produced the fatal injury"  [@icd10v2ed10, s.
31]. In some cases, this concept is relatively unproblematic: for example, when
a person dies of cancer, the primary tumor and not any metastases is underlying
cause. In other cases, the interpretation is not as straightforward. Detailed
instructions for choice of underlying cause of death has changed between
different ICD versions, and practices for choice of underlying cause may differ
between different populations using the same ICD version. Some examples, where
the interpretation differs, which may give rise to artificial trends:

* Diabetes as underlying cause in people dying form ischemic heart disease or
  stroke.
* Pneumonia as underlying cause in people with prior diseases which increase
  the risk of pneumonia.

For ICD versions before ICD-10, causes of death are not available at detailed
level, instead, condensed lists are used, such as the so-called A-lists in
ICD-7 and ICD-8, and the BTL (Basic Tabulation List) in ICD-9. This often makes
it hard to construct meaningful categories covering the same diseases for the
different ICD versions, which is reflected, for example, the different
categories of infectious diseases discussed below.

Years where the ICD list has changed in a population has been marked with red
along the x-axis in the charts: 07A and 08A means ICD-7 and ICD-8 with A-list,
09B means ICD-9 with BTL, and 103 and 104 means ICD-10 with codes three or four
characters long, where the four-character codes is the most detailed level.
Dramatic changes in connection a list change can generally be assumed to be
artificial.

#Included populations

The populations included are those with nearly continuous coverage of
deaths and population in the @whomort data from the 1950s until the 2000s. This
means that most populations included are countries in Western Europe and
Northern America, and other high-income countries, such as Australia, New
Zeeland, and Japan. Some comments on specific populations:

Germany
:    Includes West Germany before 1990. Data for East Germany (whose
population before the countries were merged was about one fourth of the West
German population) and West Berlin are not available for the whole period, so
artifical trends could not have been avoided, lest the populations had been
separated.

Israel
:    Only data on Jewish populaton before 1975.

#Included causes of death
