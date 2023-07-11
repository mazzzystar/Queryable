# Queryable
The open-source code of Queryable, an iOS app, utilizes the CLIP model to conduct offline searches in the `Photos` album.

Unlike the object recognition-based search feature built into the iOS gallery, Queryable allows you to use natural language statements, such as `a brown dog sitting on a bench`, to search your gallery. It operates offline, ensuring that your album privacy won't be leaked to anyone, including Apple/Google.

[Website](https://queryable.app/) | [App Store](https://apps.apple.com/us/app/queryable-find-photo-by-text/id1661598353?platform=iphone)

## Performance
https://github.com/mazzzystar/Queryable/assets/6824141/4f3611a3-4fa6-4a06-8079-57d82e4c8bdd

## How does it work?
* Process all photos in your album through the CLIP Image Encoder to create a set of local image vectors.
* When a new text query is inputted, convert the text into a text vector using the Text Encoder.
* Compare the text vector with all the stored image vectors, evaluating the level of similarity between the text query and each image.
* Sort and return the top K most similar results.

The process is as follows:

![](https://mazzzystar.github.io/images/2022-12-28/Queryable-flow-chart.jpg)

For more details, please refer to my article [Run CLIP on iPhone to Search Photos](https://mazzzystar.github.io/2022/12/29/Run-CLIP-on-iPhone-to-Search-Photos/).


## Run on Xcode
Download the `ImageEncoder_float32.mlmodelc` and `TextEncoder_float32.mlmodelc` from [Google Drive](https://drive.google.com/drive/folders/12ze3UcqrXt9qeySGh_j_zWE-PWRDTzJv?usp=drive_link).

Clone this repo, put the downloaded models below `CoreMLModels/` path and run Xcode, it should work.

## How to Export Model
The principle is to separate the `TextEncoder` and `ImageEncoder` at the code level, and then load the model weights individually. Queryable uses the OpenAI [ViT-B/32](https://github.com/openai/CLIP) model, and I wrote a [Jupyter notebook](https://github.com/mazzzystar/Queryable/blob/main/PyTorch2CoreML.ipynb) to demonstrate how to separate, load, and export the Core ML model. The export results of the ImageEncoder's Core ML have a certain level of precision error, and more appropriate normalization parameters may be needed.

## Contributions
> Disclaimer: I am not a professional iOS engineer, please forgive my poor Swift code. You may focus only on the loading, computation, storage, and sorting of the model. 

You can apply Queryable to your own business product, but I don't recommend modifying the appearance directly and then listing it on the App Store. If you are interested in optimizing certain aspects, feel free to submit a PR (Pull Request).

If you have any questions/suggestions, here are some contact methods: [Discord](https://discord.com/invite/R3wNsqq3v5) | [Twitter](https://twitter.com/immazzystar) | [Reddit: r/Queryable](https://www.reddit.com/r/Queryable/).


## License
MIT License

Copyright (c) 2023 Ke Fang
