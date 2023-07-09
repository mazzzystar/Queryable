# Queryable
The open source version of Queryable, an iOS app the CLIP model on iOS to search the `Photos` album offline.

Unlike the object recognition-based search feature built into the iOS gallery, Queryable allows you to use natural language statements, such as `a brown dog sitting on a bench`, to search your gallery. It operates offline, ensuring that your album privacy won't be leaked to anyone, including Apple/Google.

[Website](https://queryable.app/) | [App Store](https://apps.apple.com/us/app/queryable-find-photo-by-text/id1661598353?platform=iphone)

## Performance
https://github.com/mazzzystar/Queryable/assets/6824141/4f3611a3-4fa6-4a06-8079-57d82e4c8bdd

## How does it work?
First, all photos in your album will be processed one by one through the CLIP Image Encoder, obtaining a set of local image vector.
When you input a new text query, the text will first pass through the Text Encoder to obtain a text vector, and this will then be compared with the stored image vectors for similarity, one by one. Finally, the top K most similar results are sorted and returned. The process is as follows:

![](https://mazzzystar.github.io/images/2022-12-28/Queryable-flow-chart.jpg)

For more details, please refer to my article [Run CLIP on iPhone to Search Photos](https://mazzzystar.github.io/2022/12/29/Run-CLIP-on-iPhone-to-Search-Photos/).


## Run on Xcode
Download the `ImageEncoder_float32.mlmodelc` and `TextEncoder_float32.mlmodelc` from [Google Drive](https://drive.google.com/drive/folders/12ze3UcqrXt9qeySGh_j_zWE-PWRDTzJv?usp=drive_link).

Clone this repo, put the downloaded models below `CoreMLModels/` path and run Xcode, it should work.

## Contributions
You can apply Queryable to your own business product, but I don't recommend modifying the appearance directly and then listing it on the App Store. You can contribute to this product by submitting commits to this repo, PRs are welcome.

If you have any questions/suggestions, here are some contact methods: [Discord](https://discord.com/invite/R3wNsqq3v5) | [Twitter](https://twitter.com/immazzystar) | [Reddit: r/Queryable](https://www.reddit.com/r/Queryable/).


## License
MIT License

Copyright (c) 2023 Ke Fang
