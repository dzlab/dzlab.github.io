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
{% highlight python %}
np.random.seed(42)
# there is no need to apply in transformation as 
data = ImageDataBunch.from_lists(path, fnames, labels, ds_tfms=None, size=224, bs=bs)
data.normalize(imagenet_stats)

data.classes

data.show_batch(rows=3, figsize=(7,8))

data.classes, data.c, len(data.train_ds), len(data.valid_ds)
{% endhighlight %}


Full jupyter notebooks:
- Audio dataset preprocessing - [notebook](https://github.com/dzlab/deepprojects/blob/master/classification/Freesound_General_Purpose_Audio_Tagging_-_PreProcessing.ipynb)
- Audio spectrogram classification - [notebook](https://github.com/dzlab/deepprojects/blob/master/classification/Freesound_General_Purpose_Audio_Tagging.ipynb)

{% include disqus.html %}
