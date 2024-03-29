from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name='phoganizer',
    version='0.1.0',
    author='qiujiangkun',
    author_email='qjk2001@gmail.com',
    description='Organizae photos by exif',
    long_description=long_description,
    long_description_content_type='text/markdown',
    url='https://github.com/qiujiangkun/Phoganizer',
    project_urls={
        "Bug Tracker": 'https://github.com/qiujiangkun/Phoganizer/issues',
    },
    classifiers=[
        'Programming Language :: Python :: 3',
        'License :: OSI Approved :: MIT License',
        'Operating System :: OS Independent'
    ],
    packages=find_packages(),
    python_requires='>=3.6',
)