---
layout: post
comments: true
title: Parsing XML into pandas DataFrame
categories: nlp
---

Markup languages such us XML are handy for storing and exchanging structured data. For NLP tasks (e.g. text classification), however we may want to work with pandas Dataframe as they are more pratical. The following illustrate an example of parsing XML data. In particulary the [Reuters-21578](http://www.daviddlewis.com/resources/testcollections/reuters21578/) collection which appeared on the Reuters newswire in 1987. A detailed description of this dataset can be find in this [link](http://www.daviddlewis.com/resources/testcollections/reuters21578/readme.txt)

### Downloading the data
First download the data, un-compressed and have a look to the different files

{% highlight bash %}
$ curl -O 'http://kdd.ics.uci.edu/databases/reuters21578/reuters21578.tar.gz'
$ tar xzf reuters21578.tar.gz --directory /data/reuters21578
$ ls /data/reuters21578
reut2-000.sgm reut2-001.sgm reut2-002.sgm reut2-003.sgm reut2-004.sgm reut2-005.sgm reut2-006.sgm reut2-007.sgm reut2-009.sgm reut2-008.sgm reut2-011.sgm reut2-010.sgm reut2-012.sgm reut2-013.sgm reut2-015.sgm reut2-014.sgm reut2-016.sgm reut2-017.sgm reut2-018.sgm reut2-019.sgm reut2-020.sgm reut2-021.sgm all-exchanges-strings.lc.txt all-places-strings.lc.txt all-topics-strings.lc.txt all-people-strings.lc.txt all-orgs-strings.lc.txt cat-descriptions_120396.txt feldman-cia-worldfactbook-data.txt lewis.dtd README.txt
{% endhighlight %}
The `lewis.dtd` file contains unsurprisingly a DTD describing the structure of the XML files. The `*.sgm` files contains the data which will be extracted, below is an snippet of one of these files.

{% highlight xml %}
<REUTERS TOPICS="NO" LEWISSPLIT="TRAIN" CGISPLIT="TRAINING-SET" OLDID="5545" NEWID="2">
    <DATE>26-FEB-1987 15:02:20.00</DATE>
    <TOPICS></TOPICS>
    <PLACES><D>usa</D></PLACES>
    <PEOPLE></PEOPLE>
    <ORGS></ORGS>
    <EXCHANGES></EXCHANGES>
    <COMPANIES></COMPANIES>
    <UNKNOWN> \nF Y\nf0708reute\nd f BC-STANDARD-OIL-&lt;SRD>-TO   02-26 0082</UNKNOWN>
    <TEXT>
        <TITLE>STANDARD OIL &lt;SRD> TO FORM FINANCIAL UNIT</TITLE>
        <DATELINE>    CLEVELAND, Feb 26 - </DATELINE>
        <BODY>Standard Oil Co and BP North America\nInc said they plan to form a venture to manage the money market\nborrowing and investment activities of both companies.\n    BP North America is a subsidiary of British Petroleum Co\nPlc &lt;BP>, which also owns a 55 pct interest in Standard Oil.\n    The venture will be called BP/Standard Financial Trading\nand will be operated by Standard Oil under the oversight of a\njoint management committee.\n\n Reuter\n</BODY>
    </TEXT>
</REUTERS>'
{% endhighlight %}


### Parsing a document
Unsurprising working with text dataset that was created manually is a tedious task, a lot of unexpected problems can be encoountered. Follwing is the list of issues in this dataset and how to solve them.
#### 1. Unicode decode errors
When trying to read file into a UTF-8 string to parse it later as XML, the following error is encountered (for file `reut2-017.sgm`):
```
UnicodeDecodeError: 'utf-8' codec can't decode byte 0xfc in position 1519554: invalid start byte
```
What's happening is that Python with `open('path', 'r').read()` tries to convert the bytes in this file (assuing they are utf-8-encoded string) to a unicode string (str). Then encounters a byte sequence which is not allowed in utf-8-encoded strings (namely this 0xfc at position 1519554). 

What we can do is read the file in binary then iterate over the lines and decode each of them in UTF-8 as follows:
{% highlight python %}
lines = []
for line in open(path, 'rb').readlines():
    line = line.decode('utf-8','ignore')
    lines.append(line)
xml_data = '\n'.join(lines)
{% endhighlight %}
#### 2. Special characters
Additionaly to the invalid utf-8 characters, the files (especially in the `<UNKNOWN>` tag), contains non valid characters that makes the XML parsing of the file fails:
```
>> objectify.parse('/data/reuters21578/reut2-016.sgm')
File "/data/reuters21578/reut2-016.sgm", line 11
    &#5;&#5;&#5;V RM
       ^
XMLSyntaxError: xmlParseCharRef: invalid xmlChar value 5, line 11, column 5
```
In this case, we have to remove those characters. The following simple RegEx patter will remove all characters of the shape `&#5;`
{% highlight python %}
import re
xml_data = open(path, 'r').read()
bad_char_pattern = re.compile(r"&#\d*;")
xml_data = bad_char_pattern.sub('', xml_data)
{% endhighlight %}

#### 3. Dates mixed with text
Dates in the `<DATE>` has the general shape of `dd-mm-yyyy hh:MM:ss.SS` but in some occasion I encoutered dates that looks like this.
```
3-MAR-1987  10:16:24.19
27-MAR-1987 13:49:54.59E RM
27-MAR-1987 13:53:00.39C M
27-MAR-1987 13:58:01.19E A RM
27-MAR-1987 13:59:06.41F
27-MAR-1987 13:59:33.80F
27-MAR-1987 13:59:45.20F
27-MAR-1987 13:59:50.01F
27-MAR-1987 13:59:53.78F
27-MAR-1987 13:59:59.61F
27-MAR-1987 14:00:04.62F
27-MAR-1987 14:01:21.93V RM
27-MAR-1987 14:01:56.71C M
27-MAR-1987 14:02:56.54V RM
27-MAR-1987 14:04:26.14F
9-APR-1987 00:00:00.00    # date added by S Finch as guesswork
31-MAR-1987 605:12:19.12
```
In this case a simple RegEx can be used to extract the date data ingoring un-wanted text.
{% highlight python %}
import re
date_pattern = re.compile(r'[0-9]+-[A-Z]{3}-[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+')
date_pattern.findall('9-APR-1987 00:00:00.00    # date added by S Finch as guesswork')[0]
{% endhighlight %}

### Code
The previous snippets are grouped together into a helper class for parsing Reuters dataset.
{% highlight python %}
class ReutersSGMLParser():
    """A helper class for parsing Reuters-21578 XGML file formats"""
    def __init__(self):
        self.bad_char_pattern = re.compile(r"&#\d*;")
        self.document_pattern = re.compile(r"<REUTERS.*?<\/REUTERS>", re.S)
        self.date_pattern = re.compile(r'[0-9]+-[A-Z]{3}-[0-9]{4} *[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+')

    def empty_row(self):
        """Get an empty rows which can be transformed into a dataframe"""
        rows = {
            'old_id'     : [],
            'new_id'     : [],
            'has_topics' : [],
            'date'       : [],
            'topics'     : [],
            'places'     : [],
            'people'     : [],
            'orgs'       : [],
            'exchanges'  : [],
            'companies'  : [],
            'title'      : [],
            'dateline'   : [],
            'body'       : [],
            'author'     : [],
            'cgi_split'  : [],
            'lewis_split': []
        }
        return rows

    def get_text(self, elem, tagname, d_tag = False):
        """Get the text of a tag or empty string"""
        txt = getattr(elem, tagname, '')
        if txt == '':
            return ''
        if d_tag:
            txt = txt.D
        txt = txt.text.strip()
        return txt

    def get_date(self, elem, tagname):
        """Get the datetime of a tag or empty string"""
        date_str = getattr(elem, tagname, '')
        if date_str == '':
            return ''
        date_str = date_str.text.strip()
        try:
            date_str = self.date_pattern.findall(date_str)[0]
        except IndexError as ie:
            print('Cannot find date patter in: %s' % date_str)
            return ''
        date = datetime.strptime(date_str, '%d-%b-%Y %H:%M:%S.%f')
        return date

    def parse_header(self, rows, doc):
        """parse the header.
        e.g. <REUTERS TOPICS="YES" LEWISSPLIT="TRAIN" CGISPLIT="TRAINING-SET" OLDID="5544" NEWID="1">"""
        items = dict(doc.items())
        rows[   'old_id'  ].append(items.get('OLDID', ''))
        rows[   'new_id'  ].append(items.get('NEWID', ''))
        rows[ 'has_topics'].append(bool(items.get('TOPICS', '')))
        rows[ 'cgi_split' ].append(items.get('CGISPLIT', ''))
        rows['lewis_split'].append(items.get('LEWISSPLIT', ''))

    def parse_string(self, str):
        # remove bad characters
        xml_data = self.bad_char_pattern.sub('', str)
        # find documents
        documents = self.document_pattern.findall(xml_data)
        # parse document's elements
        rows = self.empty_row()
        for doc in documents:
            xml_doc = objectify.fromstring(doc)
            # parse attributes of the header
            self.parse_header(rows, xml_doc)
            # read DATE
            rows[  'date'  ].append(self.get_date(xml_doc, 'DATE'))
            # read TOPICS
            rows[  'topics'  ].append(self.get_text(xml_doc, 'TOPICS', True))
            # read PLACES
            rows[  'places'  ].append(self.get_text(xml_doc, 'PLACES', True))
            # read PEOPLE
            rows[ 'people'  ].append(self.get_text(xml_doc, 'PEOPLE', True))
            # read ORGS
            rows[ 'orgs'  ].append(self.get_text(xml_doc, 'ORGS', True))
            # read EXCHANGES
            rows[ 'exchanges'  ].append(self.get_text(xml_doc, 'EXCHANGES', True))
            # read COMPANIES
            rows[ 'companies'  ].append(self.get_text(xml_doc, 'COMPANIES', True))
            # read the TEXT tag
            text = xml_doc.TEXT
            rows[ 'title'  ].append(self.get_text(text, 'TITLE'))
            rows['dateline'].append(self.get_text(text, 'DATELINE'))
            rows[  'body'  ].append(self.get_text(text, 'BODY'))
            rows[  'author'  ].append(self.get_text(text, 'AUTHOR'))
        return rows

    def parse(self, path):
        """parse a file from the Reuters dataset
        """
        # open xml file
        xml_data = ''
        try:
            xml_data = open(path, 'r', encoding="utf-8").read()
        except UnicodeDecodeError as ude:
            print('Failed to read %s as utf-8' % path)
            lines = []
            for line in open(path, 'rb').readlines():
                line = line.decode('utf-8','ignore') #.encode("utf-8")
                lines.append(line)
            xml_data = '\n'.join(lines)
        return self.parse_string(xml_data)
{% endhighlight %}
This class can used as follows to transform the raw data into a Pandas dataframe:
{% highlight python %}
parser = ReutersSGMLParser()
data = parser.empty_row()
for path in  ['/data/reuters21578reut2-000.sgm']:
    # parse current document
    rows = parser.parse(path)
    # append rows into dataset
    for key in data.keys():
        data[key] = data[key] + rows[key]

df = pd.DataFrame(data, columns=data.keys())
#df = df.astype(dtype= {"date":"datetime64[]"})
df.head()
{% endhighlight %}

{% include disqus.html %}