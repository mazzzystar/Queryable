# Queryable
<a href="https://apps.apple.com/us/app/queryable-find-photo-by-text/id1661598353?platform=iphone">
    <img src="https://github-production-user-asset-6210df.s3.amazonaws.com/6824141/252914927-51414112-236b-4f7a-a13b-5210f9203198.svg" alt="download-on-the-app-store">
</a>

[![Queryable](https://mazzzystar.github.io/images/2022-12-28/Queryable-search-result.jpg)](https://apps.apple.com/us/app/queryable-find-photo-by-text/id1661598353?platform=iphone)

The open-source code of Queryable, an iOS app, leverages the OpenAI's [CLIP](https://github.com/openai/CLIP) model to conduct offline searches in the 'Photos' album. Unlike the category-based search model built into the iOS Photos app, Queryable allows you to use natural language statements, such as `a brown dog sitting on a bench`, to search your album. Since it's offline, your album privacy won't be compromised by any company, including Apple or Google.

[Blog](https://mazzzystar.github.io/2022/12/29/Run-CLIP-on-iPhone-to-Search-Photos/) | [Website](https://queryable.app/) | [App Store](https://apps.apple.com/us/app/queryable-find-photo-by-text/id1661598353?platform=iphone)


## How does it work?
* Encode all album photos using the CLIP Image Encoder, compute image vectors, and save them.
* For each new text query, compute the corresponding text vector using the Text Encoder.
* Compare the similarity between this text vector and each image vector.
* Rank and return the top K most similar results.

The process is as follows:

![](https://mazzzystar.github.io/images/2022-12-28/Queryable-flow-chart.jpg)

For more details, please refer to my blog: [Run CLIP on iPhone to Search Photos](https://mazzzystar.github.io/2022/12/29/Run-CLIP-on-iPhone-to-Search-Photos/).


## Run on Xcode
Download the `ImageEncoder_float32.mlmodelc` and `TextEncoder_float32.mlmodelc` from [Google Drive](https://drive.google.com/drive/folders/12ze3UcqrXt9qeySGh_j_zWE-PWRDTzJv?usp=drive_link).
Clone this repo, put the downloaded models below `CoreMLModels/` path and run Xcode, it should work.

## Core ML Export
> If you only want to run Queryable, you can **skip this step** and directly use the exported model from [Google Drive](https://drive.google.com/drive/folders/12ze3UcqrXt9qeySGh_j_zWE-PWRDTzJv?usp=drive_link). If you wish to implement Queryable that supports your own native language, or do some model quantization/acceleration work, here are some guidelines.

The trick is to separate the `TextEncoder` and `ImageEncoder` at the architecture level, and then load the model weights individually. Queryable uses the OpenAI [ViT-B/32](https://github.com/openai/CLIP) model, and I wrote a [Jupyter notebook](https://github.com/mazzzystar/Queryable/blob/main/PyTorch2CoreML.ipynb) to demonstrate how to separate, load, and export the Core ML model. The export results of the ImageEncoder's Core ML have a certain level of precision error, and more appropriate normalization parameters may be needed.

## Contributions
> Disclaimer: I am not a professional iOS engineer, please forgive my poor Swift code. You may focus only on the loading, computation, storage, and sorting of the model. 

You can apply Queryable to your own product, but I don't recommend simply modifying the appearance and listing it on the App Store. 
If you are interested in optimizing certain aspects(such as https://github.com/mazzzystar/Queryable/issues/3, https://github.com/mazzzystar/Queryable/issues/4, https://github.com/mazzzystar/Queryable/issues/5, https://github.com/mazzzystar/Queryable/issues/6), feel free to submit a PR (Pull Request).

If you have any questions/suggestions, here are some contact methods: [Discord](https://discord.com/invite/R3wNsqq3v5) | [Twitter](https://twitter.com/immazzystar) | [Reddit: r/Queryable](https://www.reddit.com/r/Queryable/).

## License
MIT License

Copyright (c) 2023 Ke Fang
