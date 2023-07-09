# Queryable
The open source version of Queryable, an iOS app the CLIP model on iOS to search the `Photos` album offline.

Unlike the search function in the iPhone's default photo gallery, which relies on keywords, you can use natural sentences like "a dog chasing a balloon on the lawn" for searching in Queryable.

[Website](https://queryable.app/) | [App Store](https://apps.apple.com/us/app/queryable-find-photo-by-text/id1661598353?platform=iphone)

## How does it work?
First, all photos in your album will be processed one by one through the CLIP Image Encoder, obtaining a local image vector.
When you input a new text query, the text will first pass through the Text Encoder to obtain a text vector, and this will then be compared with the stored image vectors for similarity, one by one. Finally, the top K most similar results are sorted and returned. The process is as follows:

![](https://mazzzystar.github.io/images/2022-12-28/Queryable-flow-chart.jpg)

For more details, please refer to my article [Run CLIP on iPhone to Search Photos](https://mazzzystar.github.io/2022/12/29/Run-CLIP-on-iPhone-to-Search-Photos/).

## Performance
https://github.com/mazzzystar/Queryable/assets/6824141/b2e7f145-61fd-4221-bbb6-81676858cc3e



## Run on Xcode
Download the `ImageEncoder_float32.mlmodelc` and `TextEncoder_float32.mlmodelc` from [Google Drive](https://drive.google.com/drive/folders/12ze3UcqrXt9qeySGh_j_zWE-PWRDTzJv?usp=drive_link).

Clone this repo, put the downloaded models below `CoreMLModels/` path and run Xcode, it should work.


