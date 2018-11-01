---
layout: post
comments: true
title: Create a high qulity Image Dataset using EyeEm
categories: jekyll update
---

# Creating a high quality images dataset from EyeEm 
The following tutorial walk you through how to create a high quality image dataset from EyeEm. 
**Note**: The steps have to be repeated for each class, as we basically need to get URLs for each class once at a time.

## Get a list of URLs
### Search and scroll
Go to [EyeEm](https://www.eyeem.com/) web site and search for the images you are interested in. Try to be as specific as possible so that the search result will match the class you're trying to build the dataset for, in any case you can alway manually delete files.

Keep scrolling down until you have a enough images as you will be able to download only the visible one. I don't know if there is a maximum to what EyeEm can return but I guess the limit is your browser memory.

### Download into file
Now you must run some Javascript code in your browser which will save the URLs of all the images you want for you dataset.

Press Ctrl+Shift+J in Windows/Linux and Cmd+Opt+J in Mac, and a small window the javascript 'Console' will appear. That is where you will paste the JavaScript commands.

You will need to get the urls of each of the images in a **CSV** file. You can do this by running the following commands:



```
urls = Array.from(document.querySelectorAll('.sc-jWBwVP')).map(el=>el["children"][0].src);
window.open('data:text/csv;charset=utf-8,' + escape(urls.join('\n')));

```

**Note** if you have an Ad blocker (I highly recommend you install one, check [uBlock Origin](https://en.wikipedia.org/wiki/UBlock_Origin)), you may need to disable it momentarly for the EyeEm website otherwise you won't be able to downand the CSV file with all image URLs.

### Create directory and upload urls file into your server
Upload the urls file to the root folder and create a unique folder for each class in the same root folder.

{% highlight python %}
path = Path('./data/')
folders = ['airplane', 'motorcycle', 'ship']
for i in range(3):
    dest = path/folders[i]
    dest.mkdir(parents=True, exist_ok=True)
{% endhighlight %}

## Download images
For each class, download the images corresponding to the urls we got from EyeEm. I first tried using the fasai `download_images` helper function but it fails as the server response doesn't contains a `Content-Length` header. Instead we will just download the files manually:

{% highlight python %}
import re
import requests
from tqdm import tqdm

# pattern to find the width in a url
width_pattern = r'w\/[0-9]+\n'
# pattern to find the filename in a url
fname_pattern = re.compile('-([0-9]+)\/')

files = ['urls_airplane.csv', 'urls_motorcycle.csv', 'urls_ship.csv']
pbar = tqdm(total=len(files))
for i in range(len(files)):
    folder = path/folders[i]
    urls = open((path/files[i]).as_posix())
    for url in urls:
        # clean the url to get a specific width
        url = re.sub(width_pattern, 'w/450', url)
        # send an HTTP request to get the image
        response = requests.get(url, stream=False)
        # get the image filename
        fname = fname_pattern.search(url).group(1) + '.jpg'
        # write the response content into a file
        with open((folder/fname).as_posix(), mode='wb') as localfile:
            localfile.write(response.content)
    pbar.update(1)
{% endhighlight %}

Cleanup the dataset by removing corrupted files if any using the fastai `verify_images` helper function
{% highlight python %}
classes = ['airplane', 'motorcycle', 'ship']
for c in classes:
    print(c)
    verify_images(path/c, delete=True, max_workers=8)
{% endhighlight %}

## View data
{% highlight python %}
np.random.seed(42)
data = ImageDataBunch.from_folder(path, train=".", valid_pct=0.2,
        ds_tfms=get_transforms(), size=224, num_workers=4).normalize(imagenet_stats)

data.classes

data.show_batch(rows=3, figsize=(7,8))

data.classes, data.c, len(data.train_ds), len(data.valid_ds)
{% endhighlight %}

## Train model
{% highlight python %}
learn = create_cnn(data, models.resnet34, metrics=error_rate)
learn.fit_one_cycle(4)
{% endhighlight %}

## Interpretation
{% highlight python %}
interp = ClassificationInterpretation.from_learner(learn)
interp.plot_confusion_matrix()
{% endhighlight %}

![EyeEm top losses]({{ "/assets/eyeem_top_losses.png" | absolute_url }})

Full jupyter notebook - [link](https://github.com/dzlab/deepprojects/blob/master/classification/EyeEm_Image_Dataset_Download.ipynb)

**Note** This work is an adaptation of an original notebook by Jeremey and FastAI team - [link](https://github.com/fastai/course-v3/blob/e38ee7a2682ce6f730501ce55e9af7f98e0d6162/nbs/dl1/lesson2-download.ipynb)

{% include disqus.html %}
