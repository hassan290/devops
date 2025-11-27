from selenium import webdriver
from selenium.webdriver.common.by import By
from selenium.webdriver.chrome.options import Options
import pytest
import os

class TestBackend:

    def setup(self):
        chrome_options = Options()
        chrome_options.add_argument("--headless")
        chrome_options.add_argument("--no-sandbox")
        chrome_options.add_argument("--disable-dev-shm-usage")
        self.driver = webdriver.Chrome(options=chrome_options)

    def test_add(self, url):
        self.driver.get(f'{url}/add/1&2')
        assert "Add 1 and 2. Got 3!" == self.driver.find_element(By.TAG_NAME, "body").text

    def test_multiply(self, url):
        self.driver.get(f'{url}/multiply/2&2')
        assert "Multiply 2 and 2. Got 4!" == self.driver.find_element(By.TAG_NAME, "body").text

    def test_divide(self, url):
        self.driver.get(f'{url}/divide/10&2')
        assert "Divide 10 and 2. Got 5.0!" == self.driver.find_element(By.TAG_NAME, "body").text

    def test_subtract(self, url):
        self.driver.get(f'{url}/subtract/9&2')
        assert "Subtract 9 and 2. Got 7!" == self.driver.find_element(By.TAG_NAME, "body").text

    def teardown(self):
        self.driver.quit()