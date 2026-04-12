from three_dimension import app


if __name__ == '__main__':
    import uvicorn

    uvicorn.run('three_dimension:app', host='0.0.0.0', port=8000, reload=False)
