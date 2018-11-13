---
layout: post
comments: true
title: Audio Classification using DeepLearning for Image Classification
categories: jekyll update
---

# Audio Classification using Image Classification
The following tutorial walk you through how to create a classfier for audio files that uses Transfer Learning technique form a DeepLearning network that was training on ImageNet.

YES we will use image classification to classify audios, deal with it.

## Data
### Audio Dataset
We will be using [Freesound](https://freesound.org/) General-Purpose Audio Tagging dataset which can be grapped from Kaggle - [link](https://www.kaggle.com/c/freesound-audio-tagging).

In this dataset, there is a set of 9473 `wav` files for training in the `audio_train` folder and a set of 9400 `wav` files that constitues the test set.

Sounds in this dataset are unequally distributed in the following 41 categories of the Google's [AudioSet Ontology](https://research.google.com/audioset/):
```
"Acoustic_guitar", "Applause", "Bark", "Bass_drum", "Burping_or_eructation", "Bus", "Cello", "Chime", "Clarinet", "Computer_keyboard", "Cough", "Cowbell", "Double_bass", "Drawer_open_or_close", "Electric_piano", "Fart", "Finger_snapping", "Fireworks", "Flute", "Glockenspiel", "Gong", "Gunshot_or_gunfire", "Harmonica", "Hi-hat", "Keys_jangling", "Knock", "Laughter", "Meow", "Microwave_oven", "Oboe", "Saxophone", "Scissors", "Shatter", "Snare_drum", "Squeak", "Tambourine", "Tearing", "Telephone", "Trumpet", "Violin_or_fiddle", "Writing"
```

Once you downloaded this audio dataset, we can then start playing with

### Data PreProcessing
These audio files are uncompressed PCM 16 bit, 44.1 kHz, mono audio files which make just perfect for a classification based on spectrogram. We will be using the very handy python library [librosa](https://librosa.github.io/librosa/) to generate the spectrogram images from these audio files. Another option will be to use matplotlib [specgram()](https://matplotlib.org/gallery/images_contours_and_fields/specgram_demo.html).

The following snippet converts an audio into a spectrogram image:
{% highlight python %}
def plot_spectrogram(audio_path):
    y, sr = librosa.load(audio_path, sr=None)
    # Let's make and display a mel-scaled power (energy-squared) spectrogram
    S = librosa.feature.melspectrogram(y, sr=sr, n_mels=128)

    # Convert to log scale (dB). We'll use the peak power (max) as reference.
    log_S = librosa.power_to_db(S, ref=np.max)
    
    # Make a new figure
    plt.figure(figsize=(12,4))

    # Display the spectrogram on a mel scale
    # sample rate and hop length parameters are used to render the time axis
    librosa.display.specshow(log_S, sr=sr, x_axis='time', y_axis='mel')

    # Put a descriptive title on the plot
    plt.title('mel power spectrogram')

    # draw a color bar
    plt.colorbar(format='%+02.0f dB')

    # Make the figure layout compact
    plt.tight_layout()
{% endhighlight %}

For instance, the sounds of a Drawer that opens or closes looks like:
![Drawer_open_or_close]({{ "/assets/Drawer_open_or_close.png" | absolute_url }})

In our case, we need to store those images, unfortunate we have to plot them then store the plot. This is going to be very slow considering that we few thousands images. Following is the snippet for storing the images:
{% highlight python %}
def save_spectrogram(audio_fname, image_fname):
    y, sr = librosa.load(audio_fname, sr=None)
    S = librosa.feature.melspectrogram(y, sr=sr, n_mels=128)
    log_S = librosa.power_to_db(S, ref=np.max)
    librosa.display.specshow(log_S, sr=sr, x_axis='time', y_axis='mel')
    fig1 = plt.gcf()
    plt.axis('off')
    plt.show()
    plt.draw()
    fig1.savefig(image_fname, dpi=100)

def audio_to_spectrogram(audio_dir_path, image_dir_path=None):
    for paths in batch(audio_dir_path.ls(), 100):
        for audio_path in paths:
            audio_filename = get_filename(audio_path)
            image_fname = audio_filename.split('.')[0] + '.png'
            if image_dir_path:
                image_fname = image_dir_path.as_posix() + '/' + image_fname
            if Path(image_fname).exists(): continue
            print(image_fname)
            #plot_spectrogram(image_fname)
            try:
                save_spectrogram(audio_path.as_posix(), image_fname)
            except ValueError as verr:
                print('Failed to process %s %s' % (image_fname, verr))
        # wait between every batch for xyz seconds
        time.sleep(10)
{% endhighlight %}
Once the spectrogram files are generated for both training and test sets, we can have a look at them.

- load the labels from the csv file and have a look to the first 5
### View data
{% highlight python %}
# get the labeled data from the `train.csv` file
df_train = pd.read_csv('path/to/freesound/train.csv'); df_train.head()
	fname	        label	manually_verified
0	00044347.wav	Hi-hat	        0
1	001ca53d.wav	Saxophone	1
2	002d256b.wav	Trumpet	        0
3	0033e230.wav	Glockenspiel	1
4	00353774.wav	Cello	        1


# get the labels of the audio dataset
labels = df_train['label']; labels[:5]
0          Hi-hat
1       Saxophone
2         Trumpet
3    Glockenspiel
4           Cello
Name: label, dtype: object

# get the filenames of all spectrogram images
fnames = sorted(image_train_path); fnames[:5]
{% endhighlight %}

Now we can have a look at the data which will be piped into the DL model
**Note**: there is no need to apply any transformation (cropping, flipping, rotating, light, etc.) to the images we will be classiying. In fact, they are spectrogram and will be always generate same way, unlike the images that someone would take with a camera where the condition can change drastically.

{% highlight python %}
np.random.seed(42)
data = ImageDataBunch.from_lists(path, fnames, labels, ds_tfms=None, size=224, bs=bs)
data.normalize(imagenet_stats)
data.show_batch(rows=5, figsize=(8,8))
{% endhighlight %}
Following is an example of spectrograms with their corresponding labels:
![audio_spectrogram_batch]({{ "/assets/audio_spectrogram_batch.png" | absolute_url }})

## DeepLearning
Now the DL part can finally start

### Model training
First, create a pre-trained [ResNet-34](https://arxiv.org/abs/1512.03385) based model, and look for best **learning rate** that we will choose later when training the final layers of this network.
{% highlight python %}
learn = create_cnn(data, models.resnet34, metrics=error_rate)
learn.lr_find()
learn.recorder.plot()
{% endhighlight %}
Plotting the recorded learning rate will give us somethine like this:
![learning_rate_freezed_net]({{ "/assets/learning_rate_freezed_net.png" | absolute_url }})

Now we can training the FeedFordward last layers with the learning slice that we choosed wisely from the previous plot. Choose the ones that bounds a steep decreasing plot.

{% highlight python %}
lr=1e-2
learn.fit_one_cycle(5, slice(lr))

Total time: 36:59
epoch  train_loss  valid_loss  error_rate
1      2.573095    1.728513    0.476064    (28:29)
2      1.685420    1.314066    0.367553    (02:10)
3      1.244419    1.147185    0.324468    (02:08)
4      0.924578    1.065614    0.305851    (02:04)
5      0.744983    1.049067    0.295213    (02:06)
{% endhighlight %}


### Model Interpretation
{% highlight python %}
interp = ClassificationInterpretation.from_learner(learn)
interp.plot_confusion_matrix()
{% endhighlight %}

Full jupyter notebooks:
- Audio dataset preprocessing - [notebook](https://github.com/dzlab/deepprojects/blob/master/classification/Freesound_General_Purpose_Audio_Tagging_-_PreProcessing.ipynb)
- Audio spectrogram classification - [notebook](https://github.com/dzlab/deepprojects/blob/master/classification/Freesound_General_Purpose_Audio_Tagging.ipynb)

{% include disqus.html %}
