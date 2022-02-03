# Stock Screener

Stock Screener is an API to do screening for your Stock. Currently this stock screener can only apply to Indonesia stock market. 
There is 2 results of this screener API: financial valuation, which covers 12 financial ratio for the stock currently have, and prediction for the stock price. Prediction show from 3 algorithm: PER valuation, PBV ratio method, and Benjamin Graham formula. 
DISCLAIMER: every result from this API only to help you decide analyzing the Stock, not by any means to promt you to buy so this is not FINANCIAL ADVICE

You can usethis api directly on this link: https://stock-screener-api.herokuapp.com/
You can find python version on this - Jupyter Notebook on this repository: https://github.com/Willi8910/Stock-Value-Scraper

## Installation

Use the bundle to install necessary package

```bash 
bundle install
```

You need to create and migrate the migration as well, before that you need to set up db username and password in database.yml
```bash 
default: &default
  adapter: postgresql
  database: stock_screener
  username: 'your_username'
  password: 'your_password'
```

Then you can run this command

``` 
rails db:create
rails db:migrate
```

If you run it in local, you need to download chromedriver.exe in your respective version and put it in drive C:


## Usage

First you need to sign up for new account. To register to you can use this https://localhost:3001/signup [POST] to sign up, after that you can get the JWT token in response header
```
{
    "user": {
        "email" : "email",
        "password" : "password"
    }
}
```

To start the screener you can run this request localhost:3001/stocks [POST] with authorization header and body:
```
{
    "stock": "INDF"
}
```

From the API result you can built chart like this
![image](https://user-images.githubusercontent.com/16332498/152307104-bc8bb58b-45bf-4ab4-aa65-1012207f7308.png)

You can also get fair price results in this table
![image](https://user-images.githubusercontent.com/16332498/152307281-1a8ad128-4919-4f80-a2d2-bdcd9c769099.png)


## Contributing
Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

## License
[MIT](https://choosealicense.com/licenses/mit/)
