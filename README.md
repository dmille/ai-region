# openai-region

`openai-region` is an Emacs package that integrates with the OpenAI API to transform highlighted code in your buffer based on user prompts. It sends the entire file as context, but only transforms and returns the selected region.

## Installation

**Option 1: Using `straight.el`**

If you use [straight.el](https://github.com/radian-software/straight.el), add the following to your Emacs configuration:

```elisp
(straight-use-package
 '(openai-region :type git :host github :repo "yourusername/openai-region"))
```
